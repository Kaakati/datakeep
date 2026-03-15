# frozen_string_literal: true

module Vpn
  # Simplified IPSec connection using pre-shared key + optional username/password.
  #
  # Auto-generates a swanctl.conf from the simple credentials fields on
  # DatabaseConfig instead of requiring users to paste raw swanctl config.
  # Uses the same strongSwan/swanctl tooling as IpsecConnection.
  #
  # Typical enterprise VPN scenario:
  #   Gateway IP: 203.0.113.1
  #   Pre-shared key: s3cr3t
  #   Username: deploy@company.com
  #   Password: hunter2
  class IpsecSimpleConnection < Connection
    def connect
      config_content = database_config.ipsec_simple_config
      raise VpnError, "Failed to generate IPSec config" if config_content.blank?

      @config_path = write_temp_config(config_content, extension: ".conf")
      @swanctl_dir = Rails.root.join("tmp", "vpn", "swanctl_#{tunnel_name}")
      FileUtils.mkdir_p(@swanctl_dir)

      # Write config where swanctl expects it
      swanctl_conf = File.join(@swanctl_dir, "swanctl.conf")
      File.write(swanctl_conf, config_content)
      File.chmod(0600, swanctl_conf)

      Rails.logger.info "[VPN/IPSec-Simple] Starting tunnel #{tunnel_name} to #{database_config.vpn_gateway_ip}"

      # Load the connection into strongSwan
      system("swanctl", "--load-all", "--file", swanctl_conf, exception: false)

      # Initiate the connection
      conn_name = database_config.vpn_tunnel_name.presence || "datakeep"
      system("swanctl", "--initiate", "--child", conn_name, exception: false)

      wait_until(timeout: CONNECT_TIMEOUT) { connected? }

      Rails.logger.info "[VPN/IPSec-Simple] Tunnel #{tunnel_name} is up"
    end

    def disconnect
      conn_name = database_config.vpn_tunnel_name.presence || "datakeep"

      Rails.logger.info "[VPN/IPSec-Simple] Stopping tunnel #{tunnel_name}"

      system("swanctl", "--terminate", "--ike", conn_name, exception: false)
    ensure
      cleanup_files
    end

    def connected?
      conn_name = database_config.vpn_tunnel_name.presence || "datakeep"
      output = `swanctl --list-sas 2>/dev/null`
      output.include?(conn_name) && output.include?("ESTABLISHED")
    rescue StandardError
      false
    end

    private

    def cleanup_files
      FileUtils.rm_f(@config_path) if @config_path
      FileUtils.rm_rf(@swanctl_dir) if @swanctl_dir
    end
  end
end
