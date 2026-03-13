# frozen_string_literal: true

module Admin
  class StorageBackendsController < BaseController
    before_action :set_storage_backend, only: [ :show, :edit, :update, :destroy, :test_connection ]

    def index
      @storage_backends = StorageBackend.user_owned.includes(:user).order(created_at: :desc)
      @managed_backends = StorageBackend.managed.order(:name)
    end

    def show
    end

    def new
      @storage_backend = StorageBackends::S3Storage.new(managed: true)
    end

    def create
      @storage_backend = StorageBackends::S3Storage.new(managed_backend_params)
      @storage_backend.managed = true
      @storage_backend.user = nil

      if @storage_backend.save
        AuditLog.log(
          action: "create_managed_storage",
          user: current_user,
          resource: @storage_backend,
          ip_address: request.remote_ip
        )
        redirect_to admin_storage_backends_path, notice: "Managed storage backend created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @storage_backend.update(managed_backend_params)
        AuditLog.log(
          action: "update_managed_storage",
          user: current_user,
          resource: @storage_backend,
          ip_address: request.remote_ip
        )
        redirect_to admin_storage_backends_path, notice: "Managed storage backend updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @storage_backend.backup_job_storage_backends.any? || @storage_backend.backups.any?
        redirect_to admin_storage_backends_path, alert: "Cannot delete: storage backend is in use by backup jobs or backups."
      else
        @storage_backend.destroy
        AuditLog.log(
          action: "delete_managed_storage",
          user: current_user,
          resource: @storage_backend,
          ip_address: request.remote_ip
        )
        redirect_to admin_storage_backends_path, notice: "Managed storage backend deleted."
      end
    end

    def test_connection
      result = @storage_backend.test_connection
      if result[:success]
        redirect_to admin_storage_backends_path, notice: "Connection successful: #{result[:message]}"
      else
        redirect_to admin_storage_backends_path, alert: "Connection failed: #{result[:error]}"
      end
    end

    private

    def set_storage_backend
      @storage_backend = StorageBackend.find(params[:id])
    end

    def managed_backend_params
      params.require(:storage_backend).permit(:name).tap do |p|
        if params[:storage_backend][:config].present?
          p[:config] = params[:storage_backend][:config].permit(
            :bucket, :region, :prefix, :endpoint, :access_key_id, :secret_access_key
          ).to_h
          # Don't overwrite secret if left blank on edit
          if @storage_backend&.persisted? && p[:config][:secret_access_key].blank?
            p[:config].delete(:secret_access_key)
            existing = @storage_backend.config
            p[:config] = existing.stringify_keys.merge(p[:config].stringify_keys)
          end
        end
      end
    end
  end
end
