# frozen_string_literal: true

module Vpn
  # Manages a WireGuard tunnel via wg-quick.
  #
  # Lifecycle:
  # 1. Write config from encrypted DB field to /etc/wireguard/<tunnel>.conf
  # 2. Run `wg-quick up <tunnel>`
  # 3. Poll /sys/class/net/ for the interface
  # 4. On disconnect, run `wg-quick down <tunnel>`
  #
  # Requires: NET_ADMIN capability (Docker) or root access
  class WireguardConnection < Connection
    def connect
      @config_path = write_temp_config(database_config.vpn_config_data, extension: ".conf")
      @wg_config_path = "/etc/wireguard/#{tunnel_name}.conf"

      FileUtils.mkdir_p("/etc/wireguard")
      FileUtils.cp(@config_path, @wg_config_path)

      Rails.logger.info "[VPN/WireGuard] Starting tunnel #{tunnel_name}"

      system("wg-quick", "up", tunnel_name, exception: false)

      wait_until(timeout: 10) { connected? }

      Rails.logger.info "[VPN/WireGuard] Tunnel #{tunnel_name} is up"
    end

    def disconnect
      Rails.logger.info "[VPN/WireGuard] Stopping tunnel #{tunnel_name}"
      system("wg-quick", "down", tunnel_name, exception: false)
    ensure
      cleanup_files
    end

    def connected?
      File.exist?("/sys/class/net/#{tunnel_name}") &&
        system("wg", "show", tunnel_name, out: File::NULL, err: File::NULL)
    rescue StandardError
      false
    end

    # WireGuard tunnels are fast and lightweight — poll more frequently
    def monitor_interval
      5
    end

    private

    def cleanup_files
      FileUtils.rm_f(@config_path) if @config_path
      FileUtils.rm_f(@wg_config_path) if @wg_config_path
    end
  end
end
