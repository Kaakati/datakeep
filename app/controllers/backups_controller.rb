# frozen_string_literal: true

class BackupsController < ApplicationController
  before_action :set_backup_job, only: [ :index, :show, :destroy, :restore, :download ], if: -> { params[:backup_job_id].present? }
  before_action :set_backup, only: [ :show, :destroy, :restore, :download ]

  def index
    @backups = if @backup_job
                 @backup_job.backups.recent.includes(:storage_backend)
               else
                 Backup.joins(backup_job: :user)
                       .where(backup_jobs: { user_id: current_user.id })
                       .recent
                       .includes(:storage_backend, backup_job: :database_config)
               end

    @backups = @backups.page(params[:page]).per(25) if @backups.respond_to?(:page)
  end

  def show
  end

  def destroy
    # Prevent deletion of running or pending backups
    unless @backup.deletable?
      redirect_to backup_job_backup_path(@backup_job, @backup),
        alert: @backup.deletion_prevented_reason
      return
    end

    if @backup.completed?
      # Delete from storage first
      begin
        @backup.storage_backend.delete(@backup.file_path) if @backup.file_path.present?
      rescue StandardError => e
        Rails.logger.warn "Failed to delete backup file: #{e.message}"
      end
    end

    @backup.destroy

    AuditLog.log(
      action: "delete_backup",
      user: current_user,
      resource: @backup,
      ip_address: request.remote_ip
    )

    redirect_path = @backup_job ? backup_job_backups_path(@backup_job) : backups_path
    redirect_to redirect_path, notice: "Backup deleted successfully."
  end

  def restore
    unless @backup.restorable?
      redirect_to @backup, alert: "This backup cannot be restored."
      return
    end

    # Get target database config (can be same or different)
    target_config_id = params[:target_database_config_id] || @backup.backup_job.database_config_id
    target_config = current_user.database_configs.find_by(id: target_config_id)

    unless target_config
      redirect_to @backup, alert: "Target database configuration not found."
      return
    end

    # Create a Restore record to track this operation
    restore = Restore.create!(
      user: current_user,
      database_config: target_config,
      backup: @backup,
      status: :pending
    )

    RestoreExecutionJob.perform_later(restore.id)

    AuditLog.log(
      action: "restore_backup",
      user: current_user,
      resource: @backup,
      details: { target_database_config_id: target_config.id, restore_id: restore.id },
      ip_address: request.remote_ip
    )

    redirect_to @backup, notice: "Restore job started. This may take a while."
  end

  def download
    unless @backup.completed? && @backup.file_path.present?
      redirect_to @backup, alert: "This backup is not available for download."
      return
    end

    # Check if file exists using storage backend's exists? method
    unless @backup.storage_backend.exists?(@backup.file_path)
      redirect_to @backup, alert: "Backup file not found in storage."
      return
    end

    AuditLog.log(
      action: "download_backup",
      user: current_user,
      resource: @backup,
      ip_address: request.remote_ip
    )

    case @backup.storage_backend
    when StorageBackends::LocalStorage
      # Use storage backend to get the full resolved path
      base_path = @backup.storage_backend.base_path
      file_path = @backup.file_path.start_with?(base_path) ? @backup.file_path : File.join(base_path, @backup.file_path)

      send_file file_path, filename: @backup.file_name, type: "application/octet-stream"
    when StorageBackends::S3Storage
      # Download to temp file and serve
      temp_file = File.join(Dir.tmpdir, "#{SecureRandom.hex(8)}_#{@backup.file_name}")
      begin
        @backup.storage_backend.retrieve(@backup.file_path, temp_file)
        send_file temp_file, filename: @backup.file_name, type: "application/octet-stream"
      ensure
        # Clean up temp file after sending (Rails handles this via X-Sendfile or after response)
        File.delete(temp_file) if File.exist?(temp_file) && !response.sending?
      end
    else
      redirect_to @backup, alert: "Download not supported for this storage type."
    end
  end

  private

  def set_backup_job
    @backup_job = current_user.backup_jobs.find(params[:backup_job_id])
  end

  def set_backup
    @backup = if @backup_job
                @backup_job.backups.find(params[:id])
              else
                Backup.joins(backup_job: :user)
                      .where(backup_jobs: { user_id: current_user.id })
                      .find(params[:id])
              end
    # Ensure @backup_job is set from backup if not already set (for non-nested routes)
    @backup_job ||= @backup.backup_job
  end
end
