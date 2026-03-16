# frozen_string_literal: true

class HealthCheckJob
  include Sidekiq::Job
  include VpnConnectable

  sidekiq_options queue: :maintenance, retry: 1

  def perform(database_config_id = nil)
    if database_config_id
      check_single(database_config_id)
    else
      check_all
    end
  end

  private

  def check_single(database_config_id)
    config = DatabaseConfig.find(database_config_id)

    with_vpn_for(config) do
      result = HealthCheckService.new(config).check_and_record!
      Rails.logger.info "[HealthCheckJob] #{config.name}: #{result[:status]}"
      result
    end
  end

  def check_all
    Rails.logger.info "[HealthCheckJob] Starting health check for all databases"

    results = []

    DatabaseConfig.find_each do |config|
      result = with_vpn_for(config) do
        HealthCheckService.new(config).check_and_record!
      end
      results << { database_config_id: config.id, database_name: config.name, **result }
    rescue StandardError => e
      Rails.logger.error "[HealthCheckJob] Failed for #{config.name}: #{e.message}"
      results << { database_config_id: config.id, database_name: config.name, status: "unhealthy", error: e.message }
    end

    healthy_count = results.count { |r| r[:status] == "healthy" }
    unhealthy_count = results.count { |r| r[:status] == "unhealthy" }

    Rails.logger.info "[HealthCheckJob] Completed: #{healthy_count} healthy, #{unhealthy_count} unhealthy"

    results
  end
end
