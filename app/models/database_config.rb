# frozen_string_literal: true

class DatabaseConfig < ApplicationRecord
  belongs_to :user
  belongs_to :enterprise_quote, optional: true
  has_many :backup_jobs, dependent: :restrict_with_error
  has_many :health_checks, dependent: :delete_all
  has_many :sync_jobs_as_source, class_name: "SyncJob", foreign_key: :source_database_config_id, dependent: :restrict_with_error
  has_many :sync_job_targets, dependent: :destroy

  encrypts :encrypted_password
  encrypts :vpn_config_data
  encrypts :ssh_private_key
  encrypts :proxy_password
  encrypts :vpn_preshared_key
  encrypts :vpn_password

  DATABASE_TYPES = DatabaseAdapterFactory::SUPPORTED_DATABASE_TYPES.freeze
  SSL_MODES = %w[disable allow prefer require verify-ca verify-full].freeze
  VPN_TYPES = %w[openvpn ipsec ipsec_simple wireguard ssh_tunnel socks5_proxy http_proxy].freeze
  DEFAULT_PORTS = { "postgresql" => 5432, "mysql" => 3306, "mongodb" => 27017 }.freeze

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 65536 }
  validates :database_name, presence: true
  validates :username, presence: true
  validates :database_type, presence: true, inclusion: { in: DatabaseAdapterFactory::SUPPORTED_DATABASE_TYPES }
  validates :ssl_mode, inclusion: { in: %w[disable allow prefer require verify-ca verify-full] }, allow_blank: true
  validates :vpn_type, inclusion: { in: VPN_TYPES }, if: :vpn_enabled?
  validates :vpn_config_data, presence: true, if: -> { vpn_enabled? && vpn_type.in?(%w[openvpn ipsec wireguard]) }
  validates :vpn_gateway_ip, presence: true, if: -> { vpn_enabled? && vpn_type.in?(%w[openvpn ipsec wireguard ipsec_simple]) }
  validates :vpn_tunnel_name, presence: true, if: -> { vpn_enabled? && vpn_type.in?(%w[openvpn ipsec wireguard]) }
  validates :ssh_host, :ssh_user, presence: true, if: -> { vpn_type == "ssh_tunnel" }
  validates :proxy_host, :proxy_port, presence: true, if: -> { vpn_type&.end_with?("_proxy") }
  validates :vpn_preshared_key, presence: true, if: -> { vpn_type == "ipsec_simple" }
  validates :quote_database_index, uniqueness: { scope: :enterprise_quote_id, message: "slot already assigned" },
            if: -> { enterprise_quote_id.present? }

  before_validation :generate_vpn_tunnel_name, if: -> { vpn_enabled? && vpn_tunnel_name.blank? && name.present? }

  HEALTH_STATUSES = %w[unknown healthy unhealthy].freeze

  scope :healthy, -> { where(health_status: "healthy") }
  scope :unhealthy, -> { where(health_status: "unhealthy") }

  # Get the most recent backup for this database config
  def last_backup
    @last_backup ||= Backup.joins(:backup_job)
                           .where(backup_jobs: { database_config_id: id })
                           .order(created_at: :desc)
                           .first
  end

  def last_backup_at
    last_backup&.created_at
  end

  def password
    encrypted_password
  end

  def password=(value)
    self.encrypted_password = value
  end

  def connection_params
    {
      host: @tunneled_host || host,
      port: @tunneled_port || port,
      dbname: database_name,
      user: username,
      password: password,
      sslmode: ssl_mode.presence || "prefer"
    }.compact
  end

  def connection_string
    scheme = database_type || "postgresql"
    "#{scheme}://#{username}:***@#{host}:#{port}/#{database_name}"
  end

  def adapter
    @adapter ||= DatabaseAdapterFactory.for(self)
  end

  def test_connection
    result = adapter.test_connection
    if result[:success]
      self.engine_version = result[:server_version]
      self.health_status = "healthy"
    else
      self.health_status = "unhealthy"
    end
    self.last_health_check_at = Time.current
    save!
    result
  rescue StandardError => e
    self.health_status = "unhealthy"
    self.last_health_check_at = Time.current
    save!
    { success: false, error: e.message }
  end

  def healthy?
    health_status == "healthy"
  end

  def unhealthy?
    health_status == "unhealthy"
  end

  def quote_slot
    return nil unless enterprise_quote_id && quote_database_index
    databases = enterprise_quote&.quote_params&.dig("databases")
    databases&.at(quote_database_index)
  end

  def purchased_size_gb
    slot_size = quote_slot&.dig("size_gb")
    slot_size ? slot_size.to_f : user.plan_limits[:default_size_gb]
  end

  def vpn_configured?
    return false unless vpn_enabled? && vpn_type.present?

    case vpn_type
    when "ssh_tunnel"
      ssh_host.present? && ssh_user.present?
    when "socks5_proxy", "http_proxy"
      proxy_host.present? && proxy_port.present?
    when "ipsec_simple"
      vpn_gateway_ip.present? && vpn_preshared_key.present?
    else
      vpn_config_data.present?
    end
  end

  # Auto-generate swanctl config from simple IPSec credentials
  def ipsec_simple_config
    return nil unless vpn_type == "ipsec_simple"

    conn_name = vpn_tunnel_name.presence || "datakeep"
    config = <<~SWANCTL
      connections {
        #{conn_name} {
          version = 2
          remote_addrs = #{vpn_gateway_ip}
          local {
            auth = psk
    SWANCTL

    if vpn_username.present?
      config += <<~SWANCTL.indent(8)
        id = #{vpn_username}
      SWANCTL
    end

    config += <<~SWANCTL
          }
          remote {
            auth = psk
          }
          children {
            #{conn_name} {
              remote_ts = 0.0.0.0/0
              start_action = start
            }
          }
        }
      }
      secrets {
        ike-#{conn_name} {
          secret = "#{vpn_preshared_key}"
    SWANCTL

    if vpn_username.present?
      config += <<~SWANCTL.indent(6)
        id = #{vpn_username}
      SWANCTL
    end

    config += <<~SWANCTL
        }
    SWANCTL

    if vpn_username.present? && vpn_password.present?
      config += <<~SWANCTL
        eap-#{conn_name} {
          secret = "#{vpn_password}"
          id = #{vpn_username}
        }
      SWANCTL
    end

    config += "}\n"
    config
  end

  def display_engine_name
    DatabaseEngineHelper::ENGINE_LABELS[database_type] || database_type.to_s.capitalize
  end

  def same_engine_as?(other)
    database_type == other.database_type
  end

  def fetch_statistics
    stats = {}
    stats[:database_size] = adapter.database_size
    stats[:connections] = adapter.connection_statistics
    stats[:active_connections] = stats.dig(:connections, :total) || stats.dig(:connections, :active) || 0
    stats[:max_connections] = stats.dig(:connections, :max_connections) || 0
    stats.merge!(adapter.health_metrics)

    tables = adapter.list_tables
    stats[:table_count] = tables.size
    stats[:total_rows] = tables.sum { |t| t[:row_count] || 0 }

    stats
  rescue StandardError => e
    { error: e.message }
  end

  def format_bytes(bytes)
    return "0 B" if bytes.nil? || bytes == 0
    units = [ "B", "KB", "MB", "GB", "TB" ]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp > units.length - 1
    "%.1f %s" % [ bytes.to_f / (1024 ** exp), units[exp] ]
  end

  def run_vacuum_analyze
    return { success: false, error: "VACUUM ANALYZE is only supported for PostgreSQL" } unless database_type == "postgresql"

    adapter.vacuum_analyze
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def terminate_backend(pid)
    return { success: false, error: "Not supported for #{database_type}" } unless database_type == "postgresql"

    adapter.terminate_backend(pid)
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def long_running_queries(min_duration_seconds = 300)
    return [] unless database_type == "postgresql"

    adapter.long_running_queries(min_duration_seconds)
  rescue StandardError
    []
  end

  private

  def generate_vpn_tunnel_name
    base = "tun_#{name.parameterize(separator: '_')}"
    self.vpn_tunnel_name = base[0..14] # Linux tun name max 15 chars
  end
end
