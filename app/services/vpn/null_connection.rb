# frozen_string_literal: true

module Vpn
  # No-op passthrough for databases that don't use VPN.
  # Yields immediately with zero overhead.
  class NullConnection < Connection
    def initialize(database_config = nil)
      # No-op; database_config is optional for null connections
    end

    def connect
      # no-op
    end

    def disconnect
      # no-op
    end

    def connected?
      true
    end

    def with_connection(&block)
      yield
    end
  end
end
