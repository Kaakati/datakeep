# frozen_string_literal: true

class BackupExecutionJob < ApplicationJob
  queue_as :backups

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  # Maximum time a backup job can be in "running" state before considered stale
  STALE_RUNNING_THRESHOLD = 30.minutes

  def perform(backup_job_id)
    backup_job = BackupJob.find(backup_job_id)

    # Check if job is already running and not stale
    if backup_job.running?
      if stale_running_job?(backup_job)
        Rails.logger.warn "[BackupExecutionJob] Job #{backup_job_id} was stale (running > #{STALE_RUNNING_THRESHOLD.inspect}), resetting"
        backup_job.update!(status: "idle")
      else
        Rails.logger.info "[BackupExecutionJob] Job #{backup_job_id} already running, skipping"
        return
      end
    end

    backup_job.update!(status: "running", last_run_at: Time.current)

    backup = create_backup_record(backup_job)

    begin
      backup.start!

      service = PostgresBackupService.new(
        database_config: backup_job.database_config,
        storage_backend: backup_job.storage_backend,
        options: {
          compression: backup_job.compression,
          encryption: backup_job.encryption
        }
      )

      result = service.execute

      backup.complete!(
        file_path: result[:file_path],
        file_size: result[:file_size],
        checksum: result[:checksum]
      )

      backup_job.update!(
        status: "idle",
        last_run_at: Time.current
      )

      SchedulerService.update_next_run(backup_job)
      NotificationService.notify_backup_success(backup)

      AuditLog.log(
        action: "backup_completed",
        user: backup_job.user,
        resource: backup,
        details: { file_size: result[:file_size], duration: backup.duration }
      )

      backup
    rescue StandardError => e
      Rails.logger.error "[BackupExecutionJob] Failed: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      backup.fail!(e.message)
      backup_job.update!(status: "failed", last_run_at: Time.current)
      SchedulerService.update_next_run(backup_job)
      NotificationService.notify_backup_failure(backup)

      AuditLog.log(
        action: "backup_failed",
        user: backup_job.user,
        resource: backup,
        details: { error: e.message }
      )

      raise
    end
  end

  private

  def stale_running_job?(backup_job)
    return false unless backup_job.last_run_at
    backup_job.last_run_at < STALE_RUNNING_THRESHOLD.ago
  end

  def create_backup_record(backup_job)
    Backup.create!(
      backup_job: backup_job,
      storage_backend: backup_job.storage_backend,
      file_name: generate_file_name(backup_job),
      database_name: backup_job.database_config.database_name,
      pg_version: backup_job.database_config.pg_version,
      compressed: backup_job.compression,
      encrypted: backup_job.encryption
    )
  end

  def generate_file_name(backup_job)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    db_name = backup_job.database_config.database_name
    # pg_dump custom format has built-in compression, no need for .gz extension
    extension = ".dump"
    extension += ".enc" if backup_job.encryption
    "#{db_name}_#{timestamp}#{extension}"
  end
end
