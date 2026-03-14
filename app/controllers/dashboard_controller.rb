# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    redirect_to admin_root_path and return if current_user.admin?

    @database_configs = current_user.database_configs.includes(:backup_jobs)
    @backup_jobs = current_user.backup_jobs.includes(:database_config, :storage_backend)
    @recent_backups = Backup.joins(backup_job: :user)
                            .includes(backup_job: :database_config, storage_backend: [])
                            .where(backup_jobs: { user_id: current_user.id })
                            .recent
                            .limit(10)
    @storage_backends = current_user.storage_backends

    @stats = {
      total_databases: @database_configs.count,
      healthy_databases: @database_configs.healthy.count,
      total_backup_jobs: @backup_jobs.count,
      active_backup_jobs: @backup_jobs.enabled.count,
      total_backups: Backup.joins(backup_job: :user).where(backup_jobs: { user_id: current_user.id }).count,
      successful_backups: Backup.joins(backup_job: :user).where(backup_jobs: { user_id: current_user.id }).completed.count,
      total_storage_size: Backup.joins(backup_job: :user).where(backup_jobs: { user_id: current_user.id }).completed.sum(:file_size)
    }
  end
end
