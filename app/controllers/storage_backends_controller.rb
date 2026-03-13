# frozen_string_literal: true

class StorageBackendsController < ApplicationController
  include PlanEnforcement

  before_action :set_storage_backend, only: [ :show, :edit, :update, :destroy, :test_connection ]
  enforce_plan_limit :storage_backend, only: [ :new, :create ]

  def index
    @storage_backends = current_user.storage_backends.order(created_at: :desc)
  end

  def show
    @backup_jobs = @storage_backend.backup_jobs.includes(:database_config)
    @recent_backups = @storage_backend.backups.recent.limit(10)
  end

  def new
    @storage_backend = current_user.storage_backends.build
    @storage_type = params[:type] || "local"
  end

  def create
    storage_type = params[:storage_backend][:storage_type]
    if storage_type == "s3" && !current_user.admin? && !current_user.plan_limits[:s3_allowed]
      flash[:alert] = "S3 storage is available on the Enterprise plan. Upgrade to use cloud storage."
      redirect_to billing_path
      return
    end

    storage_class = storage_class_for(storage_type)
    @storage_backend = storage_class.new(storage_backend_params)
    @storage_backend.user = current_user

    if @storage_backend.save
      AuditLog.log(
        action: "create_storage_backend",
        user: current_user,
        resource: @storage_backend,
        ip_address: request.remote_ip
      )
      redirect_to storage_backend_path(@storage_backend), notice: "Storage backend created successfully."
    else
      @storage_type = params[:storage_backend][:storage_type]
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @storage_type = @storage_backend.storage_type
  end

  def update
    if @storage_backend.update(storage_backend_params)
      AuditLog.log(
        action: "update_storage_backend",
        user: current_user,
        resource: @storage_backend,
        ip_address: request.remote_ip
      )
      redirect_to storage_backend_path(@storage_backend), notice: "Storage backend updated successfully."
    else
      @storage_type = @storage_backend.storage_type
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @storage_backend.backup_jobs.any?
      redirect_to storage_backend_path(@storage_backend), alert: "Cannot delete storage backend with existing backup jobs."
    else
      @storage_backend.destroy
      AuditLog.log(
        action: "delete_storage_backend",
        user: current_user,
        resource: @storage_backend,
        ip_address: request.remote_ip
      )
      redirect_to storage_backends_path, notice: "Storage backend deleted successfully."
    end
  end

  def test_connection
    result = @storage_backend.test_connection

    AuditLog.log(
      action: "test_storage_backend",
      user: current_user,
      resource: @storage_backend,
      details: result,
      ip_address: request.remote_ip
    )

    if result[:success]
      redirect_to storage_backend_path(@storage_backend), notice: result[:message] || "Connection successful!"
    else
      redirect_to storage_backend_path(@storage_backend), alert: "Connection failed: #{result[:error]}"
    end
  end

  private

  def set_storage_backend
    @storage_backend = current_user.storage_backends.find(params[:id])
  end

  def storage_backend_params
    permitted = [ :name, :is_default ]

    # Handle config based on storage type - use existing type for updates
    storage_type = params.dig(:storage_backend, :storage_type) || @storage_backend&.storage_type

    config_params = case storage_type
    when "local"
      { path: params.dig(:storage_backend, :config, :path) }.compact
    when "s3"
      {
        bucket: params.dig(:storage_backend, :config, :bucket),
        region: params.dig(:storage_backend, :config, :region),
        access_key_id: params.dig(:storage_backend, :config, :access_key_id),
        secret_access_key: params.dig(:storage_backend, :config, :secret_access_key),
        prefix: params.dig(:storage_backend, :config, :prefix),
        endpoint: params.dig(:storage_backend, :config, :endpoint)
      }.compact
    else
      {}
    end

    result = params.require(:storage_backend).permit(*permitted)
    result[:config] = config_params
    result
  end

  def storage_class_for(type)
    case type
    when "local"
      StorageBackends::LocalStorage
    when "s3"
      StorageBackends::S3Storage
    else
      StorageBackend
    end
  end
end
