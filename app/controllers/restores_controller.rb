# frozen_string_literal: true

class RestoresController < ApplicationController
  before_action :set_restore, only: [:show]

  def index
    @restores = Restore.joins(:database_config)
                       .where(database_configs: { user_id: current_user.id })
                       .order(created_at: :desc)
                       .limit(50)
  end

  def show
    # @restore is set by before_action
  end

  def new
    @available_backups = Backup.joins(backup_job: :database_config)
                               .where(database_configs: { user_id: current_user.id })
                               .where(status: :completed)
                               .order(created_at: :desc)
                               .limit(50)
  end

  def create
    backup = Backup.joins(backup_job: :database_config)
                   .where(database_configs: { user_id: current_user.id })
                   .find(params[:backup_id])

    target_config = current_user.database_configs.find(params[:database_config_id])

    unless backup.restorable?
      redirect_to new_restore_path, alert: "Selected backup cannot be restored."
      return
    end

    restore = Restore.create!(
      user: current_user,
      database_config: target_config,
      backup: backup,
      status: :pending
    )

    RestoreExecutionJob.perform_later(restore.id)

    current_user.log_action("restore_started", restore, ip_address: request.remote_ip)

    redirect_to restore, notice: "Restore job started. Check back for status."
  end

  def upload
    unless params[:dump_file].present?
      redirect_to new_restore_path, alert: "Please select a backup file to upload."
      return
    end

    target_config = current_user.database_configs.find(params[:database_config_id])
    uploaded_file = params[:dump_file]

    # Save uploaded file to a permanent location
    upload_dir = Rails.root.join("storage", "uploads", current_user.id.to_s)
    FileUtils.mkdir_p(upload_dir)
    file_path = upload_dir.join("restore_#{Time.current.to_i}_#{uploaded_file.original_filename}")

    File.open(file_path, "wb") do |f|
      f.write(uploaded_file.read)
    end

    restore = Restore.create!(
      user: current_user,
      database_config: target_config,
      file_path: file_path.to_s,
      status: :pending
    )

    RestoreExecutionJob.perform_later(restore.id)

    current_user.log_action("restore_started", restore, ip_address: request.remote_ip)

    redirect_to restore, notice: "Restore from uploaded file started. Check back for status."
  end

  private

  def set_restore
    @restore = Restore.joins(:database_config)
                      .where(database_configs: { user_id: current_user.id })
                      .find(params[:id])
  end
end
