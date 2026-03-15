# frozen_string_literal: true

module VpnConnectable
  extend ActiveSupport::Concern

  private

  # Wraps the given block with a VPN connection if the database config
  # has VPN enabled. Uses the tunnel pool for connection reuse across
  # concurrent jobs. For non-VPN databases, yields immediately.
  def with_vpn_for(database_config, &block)
    if database_config.vpn_enabled?
      Vpn::TunnelPool.instance.with_tunnel(database_config, &block)
    else
      yield
    end
  end
end
