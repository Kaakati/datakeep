# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @stats = {
        total_users: User.count,
        total_databases: DatabaseConfig.count,
        healthy_databases: DatabaseConfig.where(health_status: "healthy").count,
        total_backup_jobs: BackupJob.count,
        total_backups: Backup.count,
        successful_backups: Backup.where(status: "completed").count,
        total_storage: Backup.where(status: "completed").sum(:file_size)
      }
      @recent_backups = Backup.includes(backup_job: [ :user, :database_config ]).order(created_at: :desc).limit(10)
      @recent_users = User.order(created_at: :desc).limit(5)
    end
  end
end
