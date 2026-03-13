# frozen_string_literal: true

module Admin
  class BackupJobsController < BaseController
    def index
      @backup_jobs = BackupJob.includes(:user, :database_config, :storage_backend).order(created_at: :desc)
    end

    def show
      @backup_job = BackupJob.find(params[:id])
      @recent_backups = @backup_job.backups.order(created_at: :desc).limit(20)
    end
  end
end
