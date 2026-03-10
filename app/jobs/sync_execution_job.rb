# frozen_string_literal: true

class SyncExecutionJob < ApplicationJob
  queue_as :sync

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  STALE_RUNNING_THRESHOLD = 60.minutes

  def perform(sync_job_id)
    sync_job = SyncJob.find(sync_job_id)

    if sync_job.running?
      if stale_running_job?(sync_job)
        Rails.logger.warn "[SyncExecutionJob] Job #{sync_job_id} was stale, resetting"
        sync_job.update!(status: "idle")
      else
        Rails.logger.info "[SyncExecutionJob] Job #{sync_job_id} already running, skipping"
        return
      end
    end

    sync_job.update!(status: "running", last_run_at: Time.current)

    execution = SyncExecution.create!(
      sync_job: sync_job,
      status: "running",
      started_at: Time.current,
      targets_count: sync_job.target_database_configs.count
    )

    begin
      result = SyncService.call(sync_job)

      execution.update!(
        status: result.failed.zero? ? "completed" : "completed",
        completed_at: Time.current,
        targets_succeeded: result.succeeded,
        error_message: result.errors.any? ? result.errors.map { |e| "#{e[:target]}: #{e[:error]}" }.join("; ") : nil
      )

      sync_job.update!(
        status: "idle",
        last_run_at: Time.current,
        next_run_at: Time.current + sync_job.interval_minutes.minutes
      )

      AuditLog.log(
        action: "sync_completed",
        user: sync_job.user,
        resource: sync_job,
        details: {
          succeeded: result.succeeded,
          failed: result.failed,
          duration: execution.duration&.round(2)
        }
      )

      Rails.logger.info "[SyncExecutionJob] Sync #{sync_job_id} completed: #{result.succeeded} succeeded, #{result.failed} failed"
    rescue StandardError => e
      Rails.logger.error "[SyncExecutionJob] Failed: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      execution.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: e.message
      )

      sync_job.update!(
        status: "failed",
        last_run_at: Time.current,
        next_run_at: Time.current + sync_job.interval_minutes.minutes
      )

      AuditLog.log(
        action: "sync_failed",
        user: sync_job.user,
        resource: sync_job,
        details: { error: e.message }
      )

      raise
    end
  end

  private

  def stale_running_job?(sync_job)
    return false unless sync_job.last_run_at

    sync_job.last_run_at < STALE_RUNNING_THRESHOLD.ago
  end
end
