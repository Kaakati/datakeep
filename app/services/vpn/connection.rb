# frozen_string_literal: true

module Vpn
  # Base class for VPN connections. Subclasses implement connect/disconnect
  # for specific VPN protocols (OpenVPN, IPSec).
  #
  # Provides advisory locking to prevent two workers from managing the same
  # tunnel simultaneously, and ensure-based cleanup to prevent orphaned tunnels.
  class Connection
    class VpnError < StandardError; end
    class ConnectionTimeout < VpnError; end

    CONNECT_TIMEOUT = 30 # seconds
    LOCK_TIMEOUT = 300   # seconds
    TUN_NAME_MAX = 15    # Linux tun interface name limit

    attr_reader :database_config

    def initialize(database_config)
      @database_config = database_config
    end

    # Establish the VPN tunnel
    def connect
      raise NotImplementedError, "#{self.class}#connect must be implemented"
    end

    # Tear down the VPN tunnel
    def disconnect
      raise NotImplementedError, "#{self.class}#disconnect must be implemented"
    end

    # Whether the tunnel is currently up
    def connected?
      raise NotImplementedError, "#{self.class}#connected? must be implemented"
    end

    # Yields with the VPN tunnel active, ensuring cleanup on exit.
    # Uses PostgreSQL advisory locks to serialize access per tunnel.
    def with_connection(&block)
      with_advisory_lock do
        connect
        yield
      ensure
        safe_disconnect
      end
    end

    private

    # PostgreSQL advisory lock keyed on the tunnel name.
    # Prevents two Sidekiq workers from managing the same tunnel.
    # Retries briefly in case the previous job is still cleaning up.
    def with_advisory_lock(&block)
      lock_key = Zlib.crc32(tunnel_name)

      acquired = false
      6.times do |i|
        acquired = ActiveRecord::Base.connection.execute(
          "SELECT pg_try_advisory_lock(#{lock_key})"
        ).first["pg_try_advisory_lock"]
        break if acquired
        sleep 5
        Rails.logger.info "[VPN] Waiting for advisory lock on #{tunnel_name} (attempt #{i + 1}/6)"
      end

      unless acquired
        raise VpnError, "VPN lock on #{tunnel_name} is held by another worker"
      end

      yield
    ensure
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{lock_key})") rescue nil
    end

    def safe_disconnect
      disconnect
    rescue StandardError => e
      Rails.logger.warn "[VPN] Failed to disconnect #{tunnel_name}: #{e.message}"
    end

    def tunnel_name
      @tunnel_name ||= database_config.vpn_tunnel_name.presence ||
        "tun_#{database_config.name.parameterize(separator: '_')}"[0..TUN_NAME_MAX - 1]
    end

    # Write encrypted config data to a persistent file for the VPN daemon.
    # Uses Rails tmp/ dir instead of /tmp to avoid sudo path restrictions.
    # Returns the path; caller is responsible for cleanup via cleanup_files.
    def write_temp_config(content, extension: ".conf")
      dir = Rails.root.join("tmp", "vpn")
      FileUtils.mkdir_p(dir)
      path = dir.join("#{tunnel_name}#{extension}").to_s
      File.write(path, content)
      File.chmod(0600, path)
      path
    end

    # Poll a condition with timeout
    def wait_until(timeout: CONNECT_TIMEOUT, interval: 0.5, &block)
      deadline = Time.current + timeout
      loop do
        return true if yield
        raise ConnectionTimeout, "VPN tunnel #{tunnel_name} did not come up within #{timeout}s" if Time.current > deadline
        sleep interval
      end
    end
  end
end
