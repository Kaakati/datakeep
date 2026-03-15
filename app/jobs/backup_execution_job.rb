# frozen_string_literal: true

class BackupExecutionJob < ApplicationJob
  include VpnConnectable

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

    # Check monthly job execution limit
    if monthly_limit_reached?(backup_job)
      Rails.logger.info "[BackupExecutionJob] Job #{backup_job_id} monthly execution limit reached, skipping"
      SchedulerService.update_next_run(backup_job)
      AuditLog.log(
        action: "backup_monthly_limit_reached",
        user: backup_job.user,
        resource: backup_job,
        details: { limit: backup_job.user.plan_limits[:max_jobs_per_month] }
      )
      return
    end

    backup_job.update!(status: "running", last_run_at: Time.current)

    backends = backup_job.effective_storage_backends

    # Create one Backup record per storage backend (all pending)
    backups = backends.map do |backend|
      create_backup_record(backup_job, backend)
    end

    # Check database size against plan limit BEFORE dumping
    if (size_error = check_database_size_limit(backup_job, backups))
      return
    end

    begin
      # Run dump once (inside VPN if needed), then upload to each backend
      dump_result = with_vpn_for(backup_job.database_config) do
        service = BackupService.new(
          database_config: backup_job.database_config,
          storage_backend: nil,
          options: {
            compression: backup_job.compression,
            encryption: backup_job.encryption,
            encryption_key: backup_job.encryption_key,
            format: :custom
          }
        )
        service.dump
      end

      # Mark all backups as running
      backups.each(&:start!)

      any_failed = false

      # Upload to each backend
      backups.each_with_index do |backup, idx|
        backend = backends[idx]
        upload_result = BackupService.upload(
          storage_backend: backend,
          temp_file: dump_result.temp_file,
          file_name: dump_result.file_name
        )

        if upload_result[:success]
          backup.complete!(
            file_path: upload_result[:file_path],
            file_size: dump_result.file_size,
            checksum: dump_result.checksum
          )
          NotificationService.notify_backup_success(backup)
        else
          any_failed = true
          backup.fail!(upload_result[:error])
          NotificationService.notify_backup_failure(backup)
        end
      end

      final_status = any_failed ? "failed" : "idle"
      backup_job.update!(status: final_status, last_run_at: Time.current)
      SchedulerService.update_next_run(backup_job)

      completed_count = backups.count(&:completed?)
      failed_count = backups.count(&:failed?)

      AuditLog.log(
        action: any_failed ? "backup_partially_failed" : "backup_completed",
        user: backup_job.user,
        resource: backups.first,
        details: {
          backends_total: backends.size,
          backends_completed: completed_count,
          backends_failed: failed_count,
          file_size: dump_result.file_size,
          duration: backups.first&.duration
        }
      )
    rescue StandardError => e
      Rails.logger.error "[BackupExecutionJob] Failed: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")

      # Mark any pending/running backups as failed
      backups.each do |backup|
        backup.fail!(e.message) unless backup.completed? || backup.failed?
      end

      backup_job.update!(status: "failed", last_run_at: Time.current)
      SchedulerService.update_next_run(backup_job)

      backups.each do |backup|
        NotificationService.notify_backup_failure(backup) if backup.failed?
      end

      AuditLog.log(
        action: "backup_failed",
        user: backup_job.user,
        resource: backups.first,
        details: { error: e.message }
      )

      raise
    ensure
      # Cleanup temp file
      if defined?(dump_result) && dump_result
        BackupService.new(
          database_config: backup_job.database_config,
          storage_backend: nil,
          options: {}
        ).send(:cleanup_temp_files, dump_result.temp_file)
      end
    end
  end

  private

  def check_database_size_limit(backup_job, backups)
    db_config = backup_job.database_config
    max_gb = db_config.purchased_size_gb
    return nil unless max_gb

    stats = with_vpn_for(db_config) { db_config.fetch_statistics }
    return nil if stats[:error]

    actual_size_bytes = stats[:database_size]
    return nil unless actual_size_bytes

    max_bytes = max_gb * 1_073_741_824
    return nil if actual_size_bytes <= max_bytes

    message = "Database size (#{db_config.format_bytes(actual_size_bytes)}) exceeds your plan limit " \
              "of #{max_gb} GB. Upgrade your plan to back up larger databases."

    backups.each { |b| b.fail!(message) }
    backup_job.update!(status: "failed", last_run_at: Time.current)
    SchedulerService.update_next_run(backup_job)
    backups.each { |b| NotificationService.notify_backup_failure(b) }

    AuditLog.log(
      action: "backup_size_limit_exceeded",
      user: backup_job.user,
      resource: backups.first,
      details: { actual_bytes: actual_size_bytes, limit_gb: max_gb }
    )

    true
  end

  def monthly_limit_reached?(backup_job)
    return false if backup_job.user.admin?
    limit = backup_job.user.plan_limits[:max_jobs_per_month]
    return false if limit.nil?
    backup_job.backups.where("created_at > ?", 30.days.ago).count >= limit
  end

  def stale_running_job?(backup_job)
    return false unless backup_job.last_run_at
    backup_job.last_run_at < STALE_RUNNING_THRESHOLD.ago
  end

  def create_backup_record(backup_job, storage_backend)
    Backup.create!(
      backup_job: backup_job,
      storage_backend: storage_backend,
      file_name: generate_file_name(backup_job),
      database_name: backup_job.database_config.database_name,
      engine_version: backup_job.database_config.engine_version,
      compressed: backup_job.compression,
      encrypted: backup_job.encryption
    )
  end

  def generate_file_name(backup_job)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    db_name = backup_job.database_config.database_name
    db_type = backup_job.database_config.database_type || "postgresql"
    # pg_dump custom format has built-in compression, no need for .gz extension
    extension = ".dump"
    extension += ".enc" if backup_job.encryption
    "#{db_name}_#{db_type}_#{timestamp}#{extension}"
  end
end
