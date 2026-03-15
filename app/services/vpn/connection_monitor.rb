# frozen_string_literal: true

module Vpn
  # Background thread that polls a VPN connection's health during operations.
  #
  # If the tunnel dies mid-operation, sets the `tunnel_lost?` flag so the
  # caller can raise a meaningful TunnelLostError instead of a cryptic
  # network error.
  #
  # Thread-safe via Mutex. Does NOT use ActiveRecord connections (only
  # filesystem/process checks from the connection's `connected?` method).
  class ConnectionMonitor
    attr_reader :connection

    def initialize(connection, interval: nil)
      @connection = connection
      @interval = interval || connection.try(:monitor_interval) || 10
      @mutex = Mutex.new
      @tunnel_lost = false
      @running = false
      @thread = nil
    end

    def start
      @mutex.synchronize do
        return if @running

        @running = true
        @tunnel_lost = false
      end

      @thread = Thread.new do
        Thread.current.name = "vpn-monitor-#{connection.send(:tunnel_name)}"

        loop do
          sleep @interval

          break unless running?

          unless connection.connected?
            @mutex.synchronize { @tunnel_lost = true }
            Rails.logger.error "[VPN/Monitor] Tunnel lost for #{connection.send(:tunnel_name)}"
            break
          end
        end
      end
    end

    def stop
      @mutex.synchronize { @running = false }
      @thread&.join(5)
      @thread = nil
    end

    def tunnel_lost?
      @mutex.synchronize { @tunnel_lost }
    end

    private

    def running?
      @mutex.synchronize { @running }
    end
  end
end
