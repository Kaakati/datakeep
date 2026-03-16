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

    RestoreExecutionJob.perform_async(restore.id)

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

    # Fast path: unencrypted local storage — serve directly
    if !@backup.encrypted? && @backup.storage_backend.is_a?(StorageBackends::LocalStorage)
      file_path = resolve_local_path(@backup)
      send_file file_path, filename: download_filename, type: "application/octet-stream"
      return
    end

    # All other cases: download to temp, decrypt if needed, then serve
    temp_file = download_to_temp(@backup)
    begin
      decrypt_temp_file(temp_file) if @backup.encrypted?
      send_file temp_file, filename: download_filename, type: "application/octet-stream"
    ensure
      File.delete(temp_file) if File.exist?(temp_file) && !response.sending?
    end
  end

  private

  def resolve_local_path(backup)
    base_path = backup.storage_backend.base_path
    backup.file_path.start_with?(base_path) ? backup.file_path : File.join(base_path, backup.file_path)
  end

  def download_to_temp(backup)
    temp_file = File.join(Dir.tmpdir, "#{SecureRandom.hex(8)}_#{backup.file_name}")
    case backup.storage_backend
    when StorageBackends::LocalStorage
      FileUtils.cp(resolve_local_path(backup), temp_file)
    else
      backup.storage_backend.retrieve(backup.file_path, temp_file)
    end
    temp_file
  end

  def decrypt_temp_file(temp_file)
    encryption_key = @backup.backup_job.encryption_key
    raise "Encryption key not available for this backup" unless encryption_key.present?

    decrypted_path = "#{temp_file}.decrypted"
    EncryptionService.decrypt_file(temp_file, decrypted_path, encryption_key)
    File.delete(temp_file)
    File.rename(decrypted_path, temp_file)
  end

  def download_filename
    @backup.file_name.sub(/\.enc$/, "")
  end

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
