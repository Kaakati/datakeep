# frozen_string_literal: true

module Vpn
  # Routes database tool commands through a SOCKS5 or HTTP proxy via proxychains-ng.
  #
  # Unlike VPN tunnels, proxies don't create a network interface — they wrap
  # individual commands. This connection writes a proxychains config and sets
  # an environment variable that database adapters check when building commands.
  #
  # Requires: proxychains-ng in Docker image
  class ProxyConnection < Connection
    def connect
      @config_path = write_proxychains_config

      # Set env var for database adapters to detect
      ENV["DATAKEEP_PROXYCHAINS_CONF"] = @config_path

      Rails.logger.info "[VPN/Proxy] Configured #{proxy_type} proxy #{database_config.proxy_host}:#{database_config.proxy_port}"
    end

    def disconnect
      ENV.delete("DATAKEEP_PROXYCHAINS_CONF")

      Rails.logger.info "[VPN/Proxy] Removed proxy configuration"
    ensure
      FileUtils.rm_f(@config_path) if @config_path
    end

    def connected?
      @config_path.present? && File.exist?(@config_path)
    end

    # Proxies are stateless — skip advisory locks
    def with_connection(&block)
      connect
      yield
    ensure
      safe_disconnect
    end

    private

    def proxy_type
      case database_config.vpn_type
      when "socks5_proxy" then "socks5"
      when "http_proxy" then "http"
      else "socks5"
      end
    end

    def write_proxychains_config
      auth_line = if database_config.proxy_username.present?
        "#{proxy_type}\t#{database_config.proxy_host}\t#{database_config.proxy_port}\t#{database_config.proxy_username}\t#{database_config.proxy_password}"
      else
        "#{proxy_type}\t#{database_config.proxy_host}\t#{database_config.proxy_port}"
      end

      config = <<~CONF
        # ProxyChains configuration for DataKeep
        # Auto-generated — do not edit
        strict_chain
        proxy_dns
        tcp_read_time_out 15000
        tcp_connect_time_out 8000

        [ProxyList]
        #{auth_line}
      CONF

      write_temp_config(config, extension: ".proxychains.conf")
    end
  end
end
