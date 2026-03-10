# frozen_string_literal: true

class SyncJobsController < ApplicationController
  before_action :set_sync_job, only: [ :show, :edit, :update, :destroy, :run_now, :pause, :resume ]

  def index
    @sync_jobs = current_user.sync_jobs
                             .includes(:source_database_config, :target_database_configs)
                             .order(created_at: :desc)
  end

  def show
    @recent_executions = @sync_job.sync_executions.recent.limit(20)
    @stats = {
      total: @sync_job.sync_executions.count,
      successful: @sync_job.sync_executions.where(status: "completed").count,
      failed: @sync_job.sync_executions.where(status: "failed").count,
      success_rate: @sync_job.success_rate
    }
  end

  def new
    @sync_job = current_user.sync_jobs.build(
      interval_minutes: 60,
      enabled: true
    )
  end

  def create
    @sync_job = current_user.sync_jobs.build(sync_job_params)

    if @sync_job.save
      AuditLog.log(
        action: "create_sync_job",
        user: current_user,
        resource: @sync_job,
        ip_address: request.remote_ip
      )
      redirect_to @sync_job, notice: "Sync job created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sync_job.update(sync_job_params)
      AuditLog.log(
        action: "update_sync_job",
        user: current_user,
        resource: @sync_job,
        ip_address: request.remote_ip
      )
      redirect_to @sync_job, notice: "Sync job updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @sync_job.destroy
    AuditLog.log(
      action: "delete_sync_job",
      user: current_user,
      resource: @sync_job,
      ip_address: request.remote_ip
    )
    redirect_to sync_jobs_path, notice: "Sync job deleted successfully."
  end

  def run_now
    if @sync_job.run_now!
      AuditLog.log(
        action: "run_sync_job",
        user: current_user,
        resource: @sync_job,
        ip_address: request.remote_ip
      )
      redirect_to @sync_job, notice: "Sync job started. Check back soon for results."
    else
      redirect_to @sync_job, alert: "Sync job is already running."
    end
  end

  def pause
    @sync_job.pause!
    AuditLog.log(
      action: "pause_sync_job",
      user: current_user,
      resource: @sync_job,
      ip_address: request.remote_ip
    )
    redirect_to @sync_job, notice: "Sync job paused."
  end

  def resume
    @sync_job.resume!
    AuditLog.log(
      action: "resume_sync_job",
      user: current_user,
      resource: @sync_job,
      ip_address: request.remote_ip
    )
    redirect_to @sync_job, notice: "Sync job resumed."
  end

  private

  def set_sync_job
    @sync_job = current_user.sync_jobs.find(params[:id])
  end

  def sync_job_params
    params.require(:sync_job).permit(
      :name, :source_database_config_id, :interval_minutes, :enabled,
      target_database_config_ids: []
    )
  end
end
