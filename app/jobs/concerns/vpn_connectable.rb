# frozen_string_literal: true

module VpnConnectable
  extend ActiveSupport::Concern

  private

  # Wraps the given block with a VPN connection if the database config
  # has VPN enabled. For non-VPN databases, yields immediately (NullConnection).
  def with_vpn_for(database_config, &block)
    Vpn::ConnectionFactory.with_connection_for(database_config, &block)
  end
end
