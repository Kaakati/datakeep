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
    SWANCTL_CONF_DIR = "/etc/swanctl/conf.d"

    def connect
      write_swanctl_config
      reload_swanctl
      initiate_connection

      wait_until(timeout: CONNECT_TIMEOUT) { connected? }

      Rails.logger.info "[VPN/IPSec] Tunnel #{tunnel_name} is up"
    end

    def disconnect
      Rails.logger.info "[VPN/IPSec] Terminating tunnel #{tunnel_name}"

      terminate_connection
      remove_swanctl_config
      reload_swanctl
    end

    def connected?
      output = `swanctl --list-sas --ike #{tunnel_name} 2>/dev/null`
      # Both IKE SA and CHILD SA must be ESTABLISHED
      output.include?("ESTABLISHED") && output.match?(/CHILD_SA.*INSTALLED/i)
    rescue StandardError
      false
    end

    private

    def config_file_path
      File.join(SWANCTL_CONF_DIR, "#{tunnel_name}.conf")
    end

    def write_swanctl_config
      config_content = database_config.vpn_config_data

      # Inject connection name if not already present
      unless config_content.include?(tunnel_name)
        config_content = config_content.sub(
          /connections\s*\{/,
          "connections {\n    #{tunnel_name} {"
        )
      end

      File.write(config_file_path, config_content)
      Rails.logger.info "[VPN/IPSec] Wrote config to #{config_file_path}"
    end

    def remove_swanctl_config
      FileUtils.rm_f(config_file_path)
    end

    def reload_swanctl
      result = system("swanctl", "--load-all", exception: false)
      Rails.logger.warn "[VPN/IPSec] swanctl --load-all returned non-zero" unless result
    end

    def initiate_connection
      Rails.logger.info "[VPN/IPSec] Initiating connection #{tunnel_name}"
      success = system("swanctl", "--initiate", "--ike", tunnel_name, exception: false)
      raise VpnError, "swanctl --initiate failed for #{tunnel_name}" unless success
    end

    def terminate_connection
      system("swanctl", "--terminate", "--ike", tunnel_name, exception: false)
    rescue StandardError => e
      Rails.logger.warn "[VPN/IPSec] Terminate failed: #{e.message}"
    end
  end
end
