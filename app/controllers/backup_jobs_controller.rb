# frozen_string_literal: true

class BackupJobsController < ApplicationController
  include PlanEnforcement

  before_action :set_backup_job, only: [ :show, :edit, :update, :destroy, :run_now, :pause, :resume ]
  enforce_plan_limit :backup_job, only: [ :new, :create ]

  def index
    @backup_jobs = current_user.backup_jobs
                               .includes(:database_config, :storage_backend, :storage_backends)
                               .order(created_at: :desc)
  end

  def show
    @recent_backups = @backup_job.backups.recent.limit(20)
    @stats = {
      total: @backup_job.backups.count,
      successful: @backup_job.backups.completed.count,
      failed: @backup_job.backups.failed.count,
      success_rate: @backup_job.success_rate
    }
  end

  def new
    @backup_job = current_user.backup_jobs.build(
      schedule_type: "daily",
      compression: true,
      encryption: false,
      retention_days: 30,
      enabled: true
    )
  end

  def create
    @backup_job = current_user.backup_jobs.build(backup_job_params)
    sync_legacy_storage_backend(@backup_job)

    if @backup_job.save
      AuditLog.log(
        action: "create_backup_job",
        user: current_user,
        resource: @backup_job,
        ip_address: request.remote_ip
      )
      redirect_to @backup_job, notice: "Backup job created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    sync_legacy_storage_backend(@backup_job, backup_job_params)

    if @backup_job.update(backup_job_params)
      AuditLog.log(
        action: "update_backup_job",
        user: current_user,
        resource: @backup_job,
        ip_address: request.remote_ip
      )
      redirect_to @backup_job, notice: "Backup job updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @backup_job.destroy
    AuditLog.log(
      action: "delete_backup_job",
      user: current_user,
      resource: @backup_job,
      ip_address: request.remote_ip
    )
    redirect_to backup_jobs_path, notice: "Backup job deleted successfully."
  end

  def run_now
    if @backup_job.run_now!
      AuditLog.log(
        action: "run_backup_job",
        user: current_user,
        resource: @backup_job,
        ip_address: request.remote_ip
      )
      redirect_to @backup_job, notice: "Backup job started. Check back soon for results."
    else
      redirect_to @backup_job, alert: "Backup job is already running."
    end
  end

  def pause
    @backup_job.pause!
    AuditLog.log(
      action: "pause_backup_job",
      user: current_user,
      resource: @backup_job,
      ip_address: request.remote_ip
    )
    redirect_to @backup_job, notice: "Backup job paused."
  end

  def resume
    @backup_job.resume!
    AuditLog.log(
      action: "resume_backup_job",
      user: current_user,
      resource: @backup_job,
      ip_address: request.remote_ip
    )
    redirect_to @backup_job, notice: "Backup job resumed."
  end

  private

  def set_backup_job
    @backup_job = current_user.backup_jobs.find(params[:id])
  end

  def backup_job_params
    params.require(:backup_job).permit(
      :name, :database_config_id, :storage_backend_id,
      :schedule_type, :cron_expression,
      :compression, :encryption, :retention_days, :enabled,
      notification_channel_ids: [],
      storage_backend_ids: []
    )
  end

  # Keep legacy storage_backend_id in sync with first selected backend
  def sync_legacy_storage_backend(backup_job, params_hash = backup_job_params)
    ids = params_hash[:storage_backend_ids]
    return unless ids.present?

    ids = ids.reject(&:blank?)
    backup_job.storage_backend_id = ids.first if ids.any?
  end
end
