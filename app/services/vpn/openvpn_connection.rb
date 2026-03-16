# frozen_string_literal: true

module Vpn
  # Manages an OpenVPN userspace tunnel.
  #
  # Lifecycle:
  # 1. Write config from encrypted DB field to temp file
  # 2. Spawn `openvpn --daemon` with the config
  # 3. Poll /sys/class/net/ for the tun interface
  # 4. On disconnect, send SIGTERM to the daemon PID
  #
  # Requires: NET_ADMIN + NET_RAW capabilities (Docker) or root access
  class OpenvpnConnection < Connection
    def connect
      @config_path = write_temp_config(database_config.vpn_config_data, extension: ".ovpn")
      @pid_path = Rails.root.join("tmp", "vpn", "openvpn_#{tunnel_name}.pid").to_s

      cmd = [
        "openvpn",
        "--config", @config_path,
        "--daemon", "datakeep_#{tunnel_name}",
        "--writepid", @pid_path,
        "--connect-retry-max", "3",
        "--connect-timeout", CONNECT_TIMEOUT.to_s,
        "--verb", "3",
        "--log", log_path
      ]

      # Add remote gateway if specified separately from config
      if database_config.vpn_gateway_ip.present?
        cmd += ["--remote", database_config.vpn_gateway_ip]
      end

      Rails.logger.info "[VPN/OpenVPN] Starting tunnel #{tunnel_name}"

      system(*cmd, exception: false)

      begin
        wait_until(timeout: CONNECT_TIMEOUT) { connected? }
        Rails.logger.info "[VPN/OpenVPN] Tunnel #{tunnel_name} is up"
      rescue ConnectionTimeout => e
        dump_openvpn_log
        raise
      end
    end

    def disconnect
      pid = read_pid
      return unless pid

      Rails.logger.info "[VPN/OpenVPN] Stopping tunnel #{tunnel_name} (PID #{pid})"

      begin
        Process.kill("TERM", pid)
        # Wait briefly for process to exit
        5.times do
          break unless process_alive?(pid)
          sleep 0.5
        end
        # Force kill if still alive
        Process.kill("KILL", pid) if process_alive?(pid)
      rescue Errno::ESRCH
        # Process already gone — fine
      end
    ensure
      cleanup_files
    end

    def connected?
      return false unless File.exist?(log_path)

      log_content = File.read(log_path)
      log_content.include?("Initialization Sequence Completed")
    rescue StandardError
      false
    end

    private

    def read_pid
      return nil unless @pid_path
      content = File.read(@pid_path)
      return nil if content.strip.empty?
      content.strip.to_i
    rescue StandardError
      nil
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end

    def log_path
      Rails.root.join("tmp", "vpn", "openvpn_#{tunnel_name}.log").to_s
    end

    def cleanup_files
      [@config_path, @pid_path, log_path].compact.each do |path|
        FileUtils.rm_f(path)
      end
    end

    def dump_openvpn_log
      return unless File.exist?(log_path)

      lines = File.readlines(log_path).last(30).map(&:chomp)
      Rails.logger.error "[VPN/OpenVPN] Tunnel #{tunnel_name} failed. Last 30 lines of OpenVPN log:"
      lines.each { |line| Rails.logger.error "[VPN/OpenVPN] #{line}" }
    rescue StandardError => e
      Rails.logger.error "[VPN/OpenVPN] Could not read log: #{e.message}"
    end
  end
end
