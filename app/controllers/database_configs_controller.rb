# frozen_string_literal: true

class DatabaseConfigsController < ApplicationController
  include PlanEnforcement

  before_action :set_database_config, only: [ :show, :edit, :update, :destroy, :test_connection, :vacuum, :kill_query ]
  enforce_plan_limit :database_config, only: [ :new, :create ]

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

    if @database_config.healthy?
      if @database_config.vpn_enabled?
        # VPN tunnel only active during background jobs — use cached stats
        @db_stats = @database_config.cached_statistics&.deep_symbolize_keys
      else
        @db_stats = @database_config.fetch_statistics
        @long_running_queries = @database_config.long_running_queries(300)
      end
    end
  end

  def new
    @database_config = current_user.database_configs.build(
      port: 5432,
      ssl_mode: "prefer"
    )
    @available_slots = current_user.available_quote_slots
  end

  def create
    @database_config = current_user.database_configs.build(database_config_params)
    assign_quote_slot(@database_config)

    if @database_config.save
      AuditLog.log(
        action: "create_database_config",
        user: current_user,
        resource: @database_config,
        ip_address: request.remote_ip
      )

      # Automatically test the connection after creation
      connection_result = test_connection_after_save

      redirect_to @database_config, notice: connection_result[:notice], alert: connection_result[:alert]
    else
      @available_slots = current_user.available_quote_slots
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

      # Automatically test the connection after update
      connection_result = test_connection_after_save

      redirect_to @database_config, notice: connection_result[:notice], alert: connection_result[:alert]
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

  def vacuum
    result = @database_config.run_vacuum_analyze

    AuditLog.log(
      action: "vacuum_database",
      user: current_user,
      resource: @database_config,
      details: result,
      ip_address: request.remote_ip
    )

    if result[:success]
      redirect_to @database_config, notice: "VACUUM ANALYZE completed successfully."
    else
      redirect_to @database_config, alert: "VACUUM ANALYZE failed: #{result[:error]}"
    end
  end

  def kill_query
    pid = params[:pid].to_i
    if pid <= 0
      redirect_to @database_config, alert: "Invalid process ID."
      return
    end

    result = @database_config.terminate_backend(pid)

    AuditLog.log(
      action: "kill_query",
      user: current_user,
      resource: @database_config,
      details: result.merge(pid: pid),
      ip_address: request.remote_ip
    )

    if result[:success] && result[:terminated]
      redirect_to @database_config, notice: "Query (PID: #{pid}) terminated successfully."
    elsif result[:success]
      redirect_to @database_config, alert: "Query (PID: #{pid}) could not be terminated. It may have already finished."
    else
      redirect_to @database_config, alert: "Failed to terminate query: #{result[:error]}"
    end
  end

  private

  def set_database_config
    @database_config = current_user.database_configs.find(params[:id])
  end

  def database_config_params
    params.require(:database_config).permit(
      :name, :host, :port, :database_name, :username, :password, :ssl_mode,
      :vpn_enabled, :vpn_type, :vpn_config_data, :vpn_gateway_ip, :vpn_tunnel_name
    )
  end

  def assign_quote_slot(database_config)
    slot_index = params.dig(:database_config, :quote_database_index)
    return unless slot_index.present? && current_user.enterprise_plan?

    quote = current_user.active_enterprise_quote
    database_config.enterprise_quote = quote
    database_config.quote_database_index = slot_index.to_i
  end

  def test_connection_after_save
    # VPN-enabled databases need async connection test — tunnel setup is too slow for HTTP
    if @database_config.vpn_enabled?
      HealthCheckJob.perform_later(@database_config.id)
      return { notice: "Database saved. Connection test queued (VPN tunnel setup required).", alert: nil }
    end

    result = @database_config.test_connection

    AuditLog.log(
      action: "auto_test_database_config",
      user: current_user,
      resource: @database_config,
      details: result,
      ip_address: request.remote_ip
    )

    if result[:success]
      { notice: "Database saved and connection verified! PostgreSQL #{@database_config.pg_version}", alert: nil }
    else
      { notice: "Database saved.", alert: "Connection test failed: #{result[:error]}" }
    end
  rescue StandardError => e
    # Don't let connection test failures prevent saving
    Rails.logger.error("Auto connection test failed: #{e.message}")
    { notice: "Database saved.", alert: "Connection test failed: #{e.message}" }
  end
end
