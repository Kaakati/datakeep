# frozen_string_literal: true

module Admin
  class DatabaseConfigsController < BaseController
    def index
      @database_configs = DatabaseConfig.includes(:user).order(created_at: :desc)
    end

    def show
      @database_config = DatabaseConfig.find(params[:id])
      @health_checks = @database_config.health_checks.order(created_at: :desc).limit(20)
    end
  end
end
