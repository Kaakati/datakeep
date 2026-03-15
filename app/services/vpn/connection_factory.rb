# frozen_string_literal: true

module Vpn
  # Registry-based factory for VPN connections.
  # Mirrors the DatabaseAdapterFactory pattern.
  #
  # Usage:
  #   Vpn::ConnectionFactory.with_connection_for(database_config) { do_work }
  #
  class ConnectionFactory
    @connections = {}

    class << self
      # Register a connection class for a VPN type
      def register(type, connection_class)
        @connections[type.to_s] = connection_class
      end

      # Build the appropriate connection for a database config.
      # Returns NullConnection if VPN is not enabled.
      def for(database_config)
        return NullConnection.new unless database_config.vpn_enabled?

        type = database_config.vpn_type
        connection_class = @connections[type.to_s]
        raise Connection::VpnError, "Unknown VPN type: #{type}" unless connection_class

        connection_class.new(database_config)
      end

      # Convenience: build connection and yield with it active
      def with_connection_for(database_config, &block)
        self.for(database_config).with_connection(&block)
      end

      # List registered VPN types
      def supported_types
        @connections.keys
      end

      # Check if a VPN type is supported
      def supports?(type)
        @connections.key?(type.to_s)
      end

      # Reset registry (for testing)
      def reset!
        @connections = {}
      end
    end

    # Register built-in connection types
    register :openvpn, OpenvpnConnection
    register :ipsec, IpsecConnection
    register :wireguard, WireguardConnection
    register :ipsec_simple, IpsecSimpleConnection
    register :ssh_tunnel, SshTunnelConnection
    register :socks5_proxy, ProxyConnection
    register :http_proxy, ProxyConnection
  end
end
