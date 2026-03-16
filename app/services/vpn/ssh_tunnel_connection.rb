# frozen_string_literal: true

require "socket"
require "zlib"

module Vpn
  # Manages an SSH port-forwarding tunnel to reach databases behind bastion hosts.
  #
  # Lifecycle:
  # 1. Write SSH private key to temp file
  # 2. Spawn `ssh -f -N -L local_port:db_host:db_port user@ssh_host`
  # 3. Poll TCPSocket to localhost:local_port
  # 4. Set @tunneled_host/@tunneled_port on database_config so adapters connect via tunnel
  # 5. On disconnect, kill SSH process and restore connection params
  #
  # Requires: openssh-client in Docker image
  class SshTunnelConnection < Connection
    def connect
      @key_path = write_temp_config(database_config.ssh_private_key, extension: ".key")

      Rails.logger.info "[VPN/SSH] Starting tunnel #{tunnel_name} -> #{database_config.ssh_host}"

      cmd = [
        "ssh",
        "-f", "-N",
        "-o", "StrictHostKeyChecking=no",
        "-o", "ExitOnForwardFailure=yes",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=3",
        "-i", @key_path,
        "-p", ssh_port.to_s,
        "-L", "#{local_port}:#{database_config.host}:#{database_config.port}",
        "#{database_config.ssh_user}@#{database_config.ssh_host}"
      ]

      system(*cmd, exception: false)

      wait_until(timeout: CONNECT_TIMEOUT) { connected? }

      # Override connection params to route through tunnel
      database_config.instance_variable_set(:@tunneled_host, "127.0.0.1")
      database_config.instance_variable_set(:@tunneled_port, local_port)

      Rails.logger.info "[VPN/SSH] Tunnel #{tunnel_name} is up on localhost:#{local_port}"
    end

    def disconnect
      # Restore original connection params
      database_config.remove_instance_variable(:@tunneled_host) if database_config.instance_variable_defined?(:@tunneled_host)
      database_config.remove_instance_variable(:@tunneled_port) if database_config.instance_variable_defined?(:@tunneled_port)

      # Kill SSH process
      kill_ssh_process
    ensure
      cleanup_files
    end

    def connected?
      TCPSocket.new("127.0.0.1", local_port).close
      true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
      false
    end

    # SSH tunnels are stateless — skip advisory locks (no tun interface to serialize)
    def with_connection(&block)
      connect
      yield
    ensure
      safe_disconnect
    end

    private

    def ssh_port
      database_config.ssh_port.presence || 22
    end

    # Deterministic local port from tunnel name, with retry on collision
    MAX_PORT_RETRIES = 3

    def local_port
      @local_port ||= find_available_port
    end

    def find_available_port
      base_port = (Zlib.crc32(tunnel_name) % 50_000) + 10_000
      MAX_PORT_RETRIES.times do |i|
        candidate = base_port + i
        return candidate if port_available?(candidate)
      end
      base_port # fall back to original, let SSH report the error
    end

    def port_available?(port)
      server = TCPServer.new("127.0.0.1", port)
      server.close
      true
    rescue Errno::EADDRINUSE
      false
    end

    def kill_ssh_process
      # Find the SSH process by its forwarding spec
      forward_spec = "#{local_port}:#{database_config.host}:#{database_config.port}"
      pid_output = `pgrep -f "ssh.*#{forward_spec}" 2>/dev/null`.strip

      pid_output.split("\n").each do |pid_str|
        pid = pid_str.to_i
        next if pid <= 0

        begin
          Process.kill("TERM", pid)
          sleep 0.5
          Process.kill("KILL", pid) if process_alive?(pid)
        rescue Errno::ESRCH
          # Process already gone
        end
      end
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end

    def cleanup_files
      FileUtils.rm_f(@key_path) if @key_path
    end
  end
end
