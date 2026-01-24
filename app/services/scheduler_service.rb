# frozen_string_literal: true

class SchedulerService
  class << self
    def schedule_due_jobs
      BackupJob.due.find_each do |job|
        schedule_job(job)
      end
    end

    def schedule_job(backup_job)
      return unless backup_job.enabled?
      return if backup_job.running?

      Rails.logger.info "[SchedulerService] Scheduling backup job #{backup_job.id}: #{backup_job.name}"

      BackupExecutionJob.perform_later(backup_job.id)
    end

    def calculate_next_run(backup_job)
      return nil unless backup_job.enabled?

      cron = Fugit.parse(backup_job.cron_schedule)
      cron&.next_time&.to_t
    end

    def update_next_run(backup_job)
      next_run = calculate_next_run(backup_job)
      backup_job.update_column(:next_run_at, next_run) if next_run
      next_run
    end

    def reschedule_all
      BackupJob.enabled.find_each do |job|
        update_next_run(job)
      end
    end

    def jobs_due_soon(within: 1.hour)
      BackupJob.enabled.where(next_run_at: Time.current..within.from_now)
    end

    def jobs_overdue
      BackupJob.enabled.where("next_run_at < ?", Time.current).where.not(status: "running")
    end
  end
end
