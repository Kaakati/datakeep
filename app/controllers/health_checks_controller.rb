# frozen_string_literal: true

class HealthChecksController < ApplicationController
  before_action :set_database_config, only: [ :index ], if: -> { params[:database_config_id].present? }

  def index
    @period = params[:period] || "today"
    @period_days = period_to_days(@period)

    if @database_config
      # Nested route: show health checks for specific database
      @health_checks = @database_config.health_checks
                                       .within_period(@period_days)
                                       .recent
      @database_configs = [ @database_config ]
    else
      # Top-level route: show health checks grid for all databases
      @database_configs = current_user.database_configs.includes(:health_checks)
      @health_checks_by_config = load_health_checks_by_config(@period_days)
    end
  end

  private

  def set_database_config
    @database_config = current_user.database_configs.find(params[:database_config_id])
  end

  def period_to_days(period)
    case period
    when "today" then 1
    when "7days" then 7
    when "30days" then 30
    else 1
    end
  end

  def load_health_checks_by_config(days)
    health_checks = HealthCheck.joins(:database_config)
                               .where(database_configs: { user_id: current_user.id })
                               .within_period(days)
                               .order(:checked_at)

    health_checks.group_by(&:database_config_id)
  end
end
