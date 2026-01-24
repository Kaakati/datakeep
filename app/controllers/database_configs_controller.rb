# frozen_string_literal: true

class DatabaseConfigsController < ApplicationController
  before_action :set_database_config, only: [ :show, :edit, :update, :destroy, :test_connection ]

  def index
    @database_configs = current_user.database_configs.order(created_at: :desc)
  end

  def show
    @backup_jobs = @database_config.backup_jobs.includes(:storage_backend)
    @backups = Backup.joins(:backup_job)
                     .where(backup_jobs: { database_config_id: @database_config.id })
                     .includes(backup_job: :storage_backend)
                     .order(created_at: :desc)
                     .limit(50)
    @health_checks = @database_config.health_checks.recent.limit(100)
    @db_stats = @database_config.fetch_statistics if @database_config.healthy?
  end

  def new
    @database_config = current_user.database_configs.build(
      port: 5432,
      ssl_mode: "prefer"
    )
  end

  def create
    @database_config = current_user.database_configs.build(database_config_params)

    if @database_config.save
      AuditLog.log(
        action: "create_database_config",
        user: current_user,
        resource: @database_config,
        ip_address: request.remote_ip
      )
      redirect_to @database_config, notice: "Database configuration created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @database_config.update(database_config_params)
      AuditLog.log(
        action: "update_database_config",
        user: current_user,
        resource: @database_config,
        ip_address: request.remote_ip
      )
      redirect_to @database_config, notice: "Database configuration updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @database_config.backup_jobs.any?
      redirect_to @database_config, alert: "Cannot delete database configuration with existing backup jobs."
    else
      @database_config.destroy
      AuditLog.log(
        action: "delete_database_config",
        user: current_user,
        resource: @database_config,
        ip_address: request.remote_ip
      )
      redirect_to database_configs_path, notice: "Database configuration deleted successfully."
    end
  end

  def test_connection
    result = @database_config.test_connection

    AuditLog.log(
      action: "test_database_config",
      user: current_user,
      resource: @database_config,
      details: result,
      ip_address: request.remote_ip
    )

    if result[:success]
      redirect_to @database_config, notice: "Connection successful! PostgreSQL version: #{@database_config.pg_version}"
    else
      redirect_to @database_config, alert: "Connection failed: #{result[:error]}"
    end
  end

  private

  def set_database_config
    @database_config = current_user.database_configs.find(params[:id])
  end

  def database_config_params
    params.require(:database_config).permit(
      :name, :host, :port, :database_name, :username, :password, :ssl_mode
    )
  end
end
