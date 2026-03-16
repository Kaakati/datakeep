# frozen_string_literal: true

require "singleton"

module Vpn
  # Singleton pool with reference counting and TTL-based expiry for VPN tunnels.
  #
  # When multiple jobs need the same VPN tunnel (e.g., 3 backup jobs for the
  # same database), the pool ensures only one tunnel is created and all jobs
  # share it. When the last job finishes, a TTL timer keeps the tunnel alive
  # briefly in case another job starts soon.
  #
  # Thread-safe via Mutex.
  class TunnelPool
    include Singleton

    TTL_SECONDS = 5 # Disconnect quickly to free VPN license slots

    def initialize
      @mutex = Mutex.new
      @entries = {} # tunnel_name => { connection:, refcount:, ttl_thread: }
    end

    # Increment refcount and connect if first user
    def checkout(database_config)
      connection = ConnectionFactory.for(database_config)
      key = tunnel_key(database_config)

      @mutex.synchronize do
        entry = @entries[key]

        if entry
          # Cancel pending TTL expiry
          entry[:ttl_thread]&.kill
          entry[:ttl_thread] = nil
          entry[:refcount] += 1

          Rails.logger.info "[VPN/Pool] Reusing tunnel #{key} (refcount: #{entry[:refcount]})"
          return entry[:connection]
        end

        # New tunnel
        @entries[key] = { connection: connection, refcount: 1, ttl_thread: nil }
      end

      # Connect outside the mutex to avoid holding the lock during slow I/O
      connection.connect

      Rails.logger.info "[VPN/Pool] Created tunnel #{key}"
      connection
    end

    # Decrement refcount; start TTL timer if zero
    def checkin(database_config)
      key = tunnel_key(database_config)

      @mutex.synchronize do
        entry = @entries[key]
        return unless entry

        entry[:refcount] -= 1

        if entry[:refcount] <= 0
          Rails.logger.info "[VPN/Pool] Tunnel #{key} idle — starting #{TTL_SECONDS}s TTL"
          entry[:ttl_thread] = Thread.new do
            sleep TTL_SECONDS
            expire_tunnel(key)
          end
        end
      end
    end

    # Checkout/yield/checkin convenience wrapper
    def with_tunnel(database_config, &block)
      checkout(database_config)
      yield
    ensure
      checkin(database_config)
    end

    # Disconnect all tunnels and clear pool (for graceful shutdown)
    def shutdown!
      @mutex.synchronize do
        @entries.each do |key, entry|
          entry[:ttl_thread]&.kill
          begin
            entry[:connection].disconnect
          rescue StandardError => e
            Rails.logger.warn "[VPN/Pool] Error disconnecting #{key}: #{e.message}"
          end
        end
        @entries.clear
      end

      Rails.logger.info "[VPN/Pool] All tunnels shut down"
    end

    # Visible for testing
    def pool_size
      @mutex.synchronize { @entries.size }
    end

    private

    def tunnel_key(database_config)
      "#{database_config.vpn_type}_#{database_config.id}"
    end

    def expire_tunnel(key)
      connection = nil

      @mutex.synchronize do
        entry = @entries[key]
        return unless entry
        return if entry[:refcount] > 0 # Someone checked out while we slept

        connection = entry[:connection]
        @entries.delete(key)
      end

      begin
        connection&.disconnect
        Rails.logger.info "[VPN/Pool] Expired tunnel #{key}"
      rescue StandardError => e
        Rails.logger.warn "[VPN/Pool] Error expiring #{key}: #{e.message}"
      end
    end
  end
end
