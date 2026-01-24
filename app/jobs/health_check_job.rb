# frozen_string_literal: true

class HealthCheckJob < ApplicationJob
  queue_as :maintenance

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
    result = HealthCheckService.new(config).check_and_record!

    Rails.logger.info "[HealthCheckJob] #{config.name}: #{result[:status]}"

    result
  end

  def check_all
    Rails.logger.info "[HealthCheckJob] Starting health check for all databases"

    results = HealthCheckService.check_all_and_record!

    healthy_count = results.count { |r| r[:status] == "healthy" }
    unhealthy_count = results.count { |r| r[:status] == "unhealthy" }

    Rails.logger.info "[HealthCheckJob] Completed: #{healthy_count} healthy, #{unhealthy_count} unhealthy"

    results
  end
end
