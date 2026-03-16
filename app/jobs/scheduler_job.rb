# frozen_string_literal: true

class SchedulerJob
  include Sidekiq::Job

  sidekiq_options queue: :scheduler, retry: 0

  def perform
    Rails.logger.info "[SchedulerJob] Checking for due backup jobs"

    backup_count = 0
    BackupJob.due.find_each do |job|
      next if job.running?

      Rails.logger.info "[SchedulerJob] Scheduling backup job: #{job.name}"
      BackupExecutionJob.perform_async(job.id)
      backup_count += 1
    end

    Rails.logger.info "[SchedulerJob] Scheduled #{backup_count} backup jobs"

    sync_count = 0
    SyncJob.due.find_each do |job|
      next if job.running?

      Rails.logger.info "[SchedulerJob] Scheduling sync job: #{job.name}"
      SyncExecutionJob.perform_async(job.id)
      sync_count += 1
    end

    Rails.logger.info "[SchedulerJob] Scheduled #{sync_count} sync jobs"

    { backup_scheduled: backup_count, sync_scheduled: sync_count }
  end
end
