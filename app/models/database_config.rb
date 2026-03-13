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

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :host, presence: true
  validates :port, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 65536 }
  validates :database_name, presence: true
  validates :username, presence: true
  validates :ssl_mode, inclusion: { in: %w[disable allow prefer require verify-ca verify-full] }, allow_blank: true
  validates :vpn_type, inclusion: { in: %w[openvpn ipsec] }, if: :vpn_enabled?
  validates :vpn_config_data, presence: true, if: :vpn_enabled?
  validates :vpn_gateway_ip, presence: true, if: :vpn_enabled?
  validates :vpn_tunnel_name, presence: true, if: :vpn_enabled?
  validates :quote_database_index, uniqueness: { scope: :enterprise_quote_id, message: "slot already assigned" },
            if: -> { enterprise_quote_id.present? }

  before_validation :generate_vpn_tunnel_name, if: -> { vpn_enabled? && vpn_tunnel_name.blank? && name.present? }

  SSL_MODES = %w[disable allow prefer require verify-ca verify-full].freeze
  VPN_TYPES = %w[openvpn ipsec].freeze
  PG_VERSIONS = %w[12 13 14 15 16 17].freeze
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
      host: host,
      port: port,
      dbname: database_name,
      user: username,
      password: password,
      sslmode: ssl_mode.presence || "prefer"
    }.compact
  end

  def connection_string
    params = connection_params.except(:password)
    "postgresql://#{username}:***@#{host}:#{port}/#{database_name}?sslmode=#{params[:sslmode]}"
  end

  def test_connection
    require "pg"
    conn = PG.connect(connection_params)
    version = conn.exec("SELECT version()").first["version"]
    self.pg_version = version.match(/PostgreSQL (\d+\.\d+)/)[1] rescue nil
    self.health_status = "healthy"
    self.last_health_check_at = Time.current
    save!
    { success: true, version: version }
  rescue PG::Error => e
    self.health_status = "unhealthy"
    self.last_health_check_at = Time.current
    save!
    { success: false, error: e.message }
  ensure
    conn&.close
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
    vpn_enabled? && vpn_type.present? && vpn_config_data.present?
  end

  def fetch_statistics
    require "pg"
    conn = PG.connect(connection_params)

    # Single combined query using CTEs for all statistics
    result = conn.exec(<<~SQL)
      WITH db_size AS (
        SELECT pg_database_size(current_database()) as size
      ),
      conn_states AS (
        SELECT
          count(*) FILTER (WHERE state = 'active') as active,
          count(*) FILTER (WHERE state = 'idle') as idle,
          count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
          count(*) FILTER (WHERE state = 'idle in transaction (aborted)') as idle_in_transaction_aborted,
          count(*) FILTER (WHERE wait_event_type IS NOT NULL AND state = 'active') as waiting,
          count(*) as total
        FROM pg_stat_activity
        WHERE datname = current_database()
      ),
      cache_stats AS (
        SELECT
          COALESCE(sum(heap_blks_read), 0) as heap_read,
          COALESCE(sum(heap_blks_hit), 0) as heap_hit,
          COALESCE(sum(idx_blks_read), 0) as idx_read,
          COALESCE(sum(idx_blks_hit), 0) as idx_hit
        FROM pg_statio_user_tables
      ),
      table_stats AS (
        SELECT
          COALESCE(sum(n_live_tup), 0) as total_rows,
          COALESCE(sum(n_dead_tup), 0) as dead_tuples,
          max(COALESCE(last_vacuum, last_autovacuum)) as last_vacuum,
          max(COALESCE(last_analyze, last_autoanalyze)) as last_analyze
        FROM pg_stat_user_tables
      ),
      counts AS (
        SELECT
          (SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE') as table_count,
          (SELECT count(*) FROM pg_indexes WHERE schemaname = 'public') as index_count
      ),
      db_stats AS (
        SELECT
          deadlocks, xact_commit, xact_rollback, temp_files, temp_bytes
        FROM pg_stat_database
        WHERE datname = current_database()
      ),
      xid_stats AS (
        SELECT
          age(datfrozenxid) as xid_age,
          current_setting('autovacuum_freeze_max_age')::bigint as freeze_max_age
        FROM pg_database
        WHERE datname = current_database()
      ),
      server_info AS (
        SELECT
          pg_postmaster_start_time() as start_time,
          current_setting('max_connections')::int as max_connections
      )
      SELECT
        ds.size as database_size,
        si.max_connections,
        si.start_time as server_start_time,
        cs.active, cs.idle, cs.idle_in_transaction, cs.idle_in_transaction_aborted, cs.waiting, cs.total as conn_total,
        ca.heap_read, ca.heap_hit, ca.idx_read, ca.idx_hit,
        ts.total_rows, ts.dead_tuples, ts.last_vacuum, ts.last_analyze,
        c.table_count, c.index_count,
        dbs.deadlocks, dbs.xact_commit, dbs.xact_rollback, dbs.temp_files, dbs.temp_bytes,
        xs.xid_age, xs.freeze_max_age
      FROM db_size ds
      CROSS JOIN conn_states cs
      CROSS JOIN cache_stats ca
      CROSS JOIN table_stats ts
      CROSS JOIN counts c
      CROSS JOIN db_stats dbs
      CROSS JOIN xid_stats xs
      CROSS JOIN server_info si
    SQL

    row = result.first
    stats = {}

    # Basic stats
    stats[:database_size] = row["database_size"].to_i
    stats[:max_connections] = row["max_connections"].to_i
    stats[:server_start_time] = row["server_start_time"]

    # Connection states
    stats[:connections] = {
      active: row["active"].to_i,
      idle: row["idle"].to_i,
      idle_in_transaction: row["idle_in_transaction"].to_i,
      idle_in_transaction_aborted: row["idle_in_transaction_aborted"].to_i,
      waiting: row["waiting"].to_i,
      total: row["conn_total"].to_i
    }
    stats[:active_connections] = row["conn_total"].to_i

    # Cache hit ratio
    heap_read = row["heap_read"].to_i
    heap_hit = row["heap_hit"].to_i
    idx_read = row["idx_read"].to_i
    idx_hit = row["idx_hit"].to_i
    total_read = heap_read + idx_read
    total_hit = heap_hit + idx_hit
    stats[:cache_hit_ratio] = if (total_read + total_hit) > 0
      ((total_hit.to_f / (total_read + total_hit)) * 100).round(2)
    else
      100.0
    end

    # Table stats
    stats[:total_rows] = row["total_rows"].to_i
    stats[:dead_tuples] = row["dead_tuples"].to_i
    stats[:last_vacuum] = row["last_vacuum"]
    stats[:last_analyze] = row["last_analyze"]
    stats[:table_count] = row["table_count"].to_i
    stats[:index_count] = row["index_count"].to_i

    # Database stats
    stats[:deadlocks] = row["deadlocks"].to_i
    stats[:commits] = row["xact_commit"].to_i
    stats[:rollbacks] = row["xact_rollback"].to_i
    stats[:temp_files] = row["temp_files"].to_i
    stats[:temp_bytes] = row["temp_bytes"].to_i

    # XID age
    stats[:xid_age] = row["xid_age"].to_i
    stats[:freeze_max_age] = row["freeze_max_age"].to_i
    stats[:xid_percent] = ((stats[:xid_age].to_f / stats[:freeze_max_age]) * 100).round(1) if stats[:freeze_max_age] > 0

    # Longest running query (separate query - needs ORDER BY LIMIT)
    long_query_result = conn.exec(<<~SQL)
      SELECT pid, now() - query_start AS duration, left(query, 200) as query, state
      FROM pg_stat_activity
      WHERE datname = current_database() AND state != 'idle' AND query NOT ILIKE '%pg_stat_activity%'
      ORDER BY query_start ASC NULLS LAST
      LIMIT 1
    SQL
    if long_query_result.any?
      lq = long_query_result.first
      stats[:longest_query] = {
        pid: lq["pid"].to_i,
        duration: lq["duration"],
        query: lq["query"],
        state: lq["state"]
      }
    end

    stats
  rescue PG::Error => e
    { error: e.message }
  ensure
    conn&.close
  end

  def format_bytes(bytes)
    return "0 B" if bytes.nil? || bytes == 0
    units = [ "B", "KB", "MB", "GB", "TB" ]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp > units.length - 1
    "%.1f %s" % [ bytes.to_f / (1024 ** exp), units[exp] ]
  end

  def run_vacuum_analyze
    require "pg"
    conn = PG.connect(connection_params)
    # VACUUM ANALYZE cannot run inside a transaction block
    conn.exec("VACUUM ANALYZE")
    { success: true }
  rescue PG::Error => e
    { success: false, error: e.message }
  ensure
    conn&.close
  end

  def terminate_backend(pid)
    require "pg"
    conn = PG.connect(connection_params)
    result = conn.exec_params("SELECT pg_terminate_backend($1)", [ pid ])
    terminated = result.first["pg_terminate_backend"] == "t"
    { success: terminated, terminated: terminated }
  rescue PG::Error => e
    { success: false, error: e.message }
  ensure
    conn&.close
  end

  def long_running_queries(min_duration_seconds = 300)
    require "pg"
    conn = PG.connect(connection_params)
    result = conn.exec_params(<<~SQL, [ min_duration_seconds ])
      SELECT
        pid,
        usename,
        state,
        query,
        EXTRACT(EPOCH FROM (now() - query_start))::integer as duration_seconds,
        query_start
      FROM pg_stat_activity
      WHERE datname = current_database()
        AND state != 'idle'
        AND query NOT ILIKE '%pg_stat_activity%'
        AND EXTRACT(EPOCH FROM (now() - query_start)) > $1
      ORDER BY query_start ASC
    SQL
    result.map do |row|
      {
        pid: row["pid"].to_i,
        username: row["usename"],
        state: row["state"],
        query: row["query"],
        duration_seconds: row["duration_seconds"].to_i,
        query_start: row["query_start"]
      }
    end
  rescue PG::Error => e
    []
  ensure
    conn&.close
  end

  private

  def generate_vpn_tunnel_name
    base = "tun_#{name.parameterize(separator: '_')}"
    self.vpn_tunnel_name = base[0..14] # Linux tun name max 15 chars
  end
end
