# frozen_string_literal: true

class SchedulerJob < ApplicationJob
  queue_as :scheduler

  def perform
    Rails.logger.info "[SchedulerJob] Checking for due backup jobs"

    due_jobs = BackupJob.due
    scheduled_count = 0

    due_jobs.find_each do |job|
      next if job.running?

      Rails.logger.info "[SchedulerJob] Scheduling backup job: #{job.name}"
      BackupExecutionJob.perform_later(job.id)
      scheduled_count += 1
    end

    Rails.logger.info "[SchedulerJob] Scheduled #{scheduled_count} backup jobs"

    { scheduled: scheduled_count }
  end
end
