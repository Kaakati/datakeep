# frozen_string_literal: true

# Separate health check for VPN-enabled databases.
# Runs less frequently than the main HealthCheckJob to avoid
# hogging limited VPN license slots (e.g., OpenVPN Access Server
# free tier = 2 concurrent connections).
#
# Checks VPN databases sequentially (one tunnel at a time) to
# minimize concurrent VPN connections.
class VpnHealthCheckJob
  include Sidekiq::Job
  include VpnConnectable

  sidekiq_options queue: :maintenance, retry: 0

  def perform
    vpn_configs = DatabaseConfig.where(vpn_enabled: true)

    Rails.logger.info "[VpnHealthCheckJob] Checking #{vpn_configs.count} VPN database(s)"

    vpn_configs.find_each do |config|
      with_vpn_for(config) do
        result = HealthCheckService.new(config).check_and_record!
        Rails.logger.info "[VpnHealthCheckJob] #{config.name}: #{result[:status]}"
      end
    rescue StandardError => e
      Rails.logger.error "[VpnHealthCheckJob] Failed for #{config.name}: #{e.message}"
    end
  end
end
