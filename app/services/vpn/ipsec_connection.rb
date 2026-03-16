# frozen_string_literal: true

module Vpn
  # Manages an IPSec tunnel via strongSwan's swanctl interface.
  #
  # Lifecycle:
  # 1. Write swanctl config from encrypted DB field to /etc/swanctl/conf.d/
  # 2. Reload swanctl configuration
  # 3. Initiate the connection
  # 4. Poll `swanctl --list-sas` for ESTABLISHED state
  # 5. On disconnect, terminate the connection and remove config
  class IpsecConnection < Connection
    def connect
      write_swanctl_config
      load_and_initiate

      wait_until(timeout: CONNECT_TIMEOUT) { connected? }

      Rails.logger.info "[VPN/IPSec] Tunnel #{tunnel_name} is up"
    end

    def disconnect
      Rails.logger.info "[VPN/IPSec] Terminating tunnel #{tunnel_name}"
      terminate_connection
    ensure
      cleanup_files
    end

    def connected?
      output = `swanctl --list-sas --ike #{tunnel_name} 2>/dev/null`
      output.include?("ESTABLISHED") && output.match?(/CHILD_SA.*INSTALLED/i)
    rescue StandardError
      false
    end

    private

    def write_swanctl_config
      config_content = database_config.vpn_config_data

      unless config_content.include?(tunnel_name)
        config_content = config_content.sub(
          /connections\s*\{/,
          "connections {\n    #{tunnel_name} {"
        )
      end

      @config_dir = Rails.root.join("tmp", "vpn", "ipsec_#{tunnel_name}")
      FileUtils.mkdir_p(@config_dir)
      @config_path = File.join(@config_dir, "swanctl.conf")
      File.write(@config_path, config_content)
      File.chmod(0600, @config_path)

      Rails.logger.info "[VPN/IPSec] Wrote config to #{@config_path}"
    end

    def load_and_initiate
      result = system("swanctl", "--load-all", "--file", @config_path, exception: false)
      Rails.logger.warn "[VPN/IPSec] swanctl --load-all returned non-zero" unless result

      Rails.logger.info "[VPN/IPSec] Initiating connection #{tunnel_name}"
      success = system("swanctl", "--initiate", "--ike", tunnel_name, exception: false)
      raise VpnError, "swanctl --initiate failed for #{tunnel_name}" unless success
    end

    def terminate_connection
      system("swanctl", "--terminate", "--ike", tunnel_name, exception: false)
    rescue StandardError => e
      Rails.logger.warn "[VPN/IPSec] Terminate failed: #{e.message}"
    end

    def cleanup_files
      FileUtils.rm_rf(@config_dir) if @config_dir
    end
  end
end
