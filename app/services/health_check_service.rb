# frozen_string_literal: true

class HealthCheckService
  class HealthCheckError < StandardError; end

  attr_reader :database_config

  def initialize(database_config)
    @database_config = database_config
  end

  def check
    result = database_config.test_connection

    if result[:success]
      {
        status: "healthy",
        version: result[:version],
        checked_at: Time.current
      }
    else
      {
        status: "unhealthy",
        error: result[:error],
        checked_at: Time.current
      }
    end
  end

  # Performs check and records it in the database for historical tracking
  def check_and_record!
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = check
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response_time_ms = ((end_time - start_time) * 1000).round

    health_check = database_config.health_checks.create!(
      status: result[:status],
      checked_at: result[:checked_at],
      response_time_ms: response_time_ms,
      error_message: result[:error]
    )

    {
      health_check: health_check,
      **result
    }
  end

  def check_all_databases(user)
    user.database_configs.map do |config|
      {
        id: config.id,
        name: config.name,
        **HealthCheckService.new(config).check
      }
    end
  end

  class << self
    def check_all
      results = []

      DatabaseConfig.find_each do |config|
        result = new(config).check
        results << {
          database_config_id: config.id,
          database_name: config.name,
          **result
        }
      end

      results
    end

    # Checks all databases and records results for historical tracking
    def check_all_and_record!
      results = []

      DatabaseConfig.find_each do |config|
        result = new(config).check_and_record!
        results << {
          database_config_id: config.id,
          database_name: config.name,
          **result
        }
      end

      results
    end

    def check_unhealthy
      DatabaseConfig.unhealthy.find_each do |config|
        new(config).check
      end
    end

    # Cleanup old health check records beyond retention period
    def cleanup!(retention_days: 30)
      HealthCheck.cleanup_old_records!(retention_days: retention_days)
    end
  end
end
