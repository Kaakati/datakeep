# frozen_string_literal: true

class VpnConnectionTestJob
  include Sidekiq::Job

  # Don't retry — the user is waiting for the result
  sidekiq_options queue: :default, retry: 0

  def perform(request_id, vpn_params)
    start_time = Time.current

    # Build a temporary struct that quacks like DatabaseConfig for VPN connections
    config = build_test_config(vpn_params)
    connection = Vpn::ConnectionFactory.for(config)

    connection.connect
    elapsed = (Time.current - start_time).round(2)

    Rails.cache.write(
      cache_key(request_id),
      { status: "success", message: "Connected in #{elapsed}s", elapsed: elapsed },
      expires_in: 5.minutes
    )
  rescue Vpn::Connection::VpnError, Vpn::Connection::ConnectionTimeout => e
    Rails.cache.write(
      cache_key(request_id),
      { status: "failed", message: e.message },
      expires_in: 5.minutes
    )
  rescue StandardError => e
    Rails.cache.write(
      cache_key(request_id),
      { status: "failed", message: "Unexpected error: #{e.message}" },
      expires_in: 5.minutes
    )
  ensure
    connection&.disconnect rescue nil
  end

  private

  def cache_key(request_id)
    "vpn_test:#{request_id}"
  end

  def build_test_config(params)
    config = OpenStruct.new(
      id: 0,
      name: "vpn_test_#{SecureRandom.hex(4)}",
      vpn_enabled?: true,
      vpn_type: params["vpn_type"],
      vpn_config_data: params["vpn_config_data"],
      vpn_gateway_ip: params["vpn_gateway_ip"],
      vpn_tunnel_name: "tun_test_#{SecureRandom.hex(3)}"[0..14],
      host: params["host"] || "127.0.0.1",
      port: (params["port"] || 5432).to_i,
      ssh_host: params["ssh_host"],
      ssh_port: (params["ssh_port"] || 22).to_i,
      ssh_user: params["ssh_user"],
      ssh_private_key: params["ssh_private_key"],
      proxy_host: params["proxy_host"],
      proxy_port: params["proxy_port"]&.to_i,
      proxy_username: params["proxy_username"],
      proxy_password: params["proxy_password"],
      vpn_preshared_key: params["vpn_preshared_key"],
      vpn_username: params["vpn_username"],
      vpn_password: params["vpn_password"]
    )

    # For ipsec_simple, generate the swanctl config dynamically
    if params["vpn_type"] == "ipsec_simple"
      config.define_singleton_method(:ipsec_simple_config) do
        DatabaseConfig.new(
          vpn_type: "ipsec_simple",
          vpn_gateway_ip: config.vpn_gateway_ip,
          vpn_preshared_key: config.vpn_preshared_key,
          vpn_username: config.vpn_username,
          vpn_password: config.vpn_password,
          vpn_tunnel_name: config.vpn_tunnel_name
        ).ipsec_simple_config
      end
    end

    config
  end
end
