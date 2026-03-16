# frozen_string_literal: true

class CleanupJob
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 1

  HEALTH_CHECK_RETENTION_DAYS = 30

  def perform
    cleanup_expired_backups
    cleanup_old_health_checks
  end

  private

  def cleanup_expired_backups
    Rails.logger.info "[CleanupJob] Starting backup cleanup"

    cleaned_count = 0
    failed_count = 0

    BackupJob.enabled.find_each do |backup_job|
      expired_backups = backup_job.backups.expired(backup_job.retention_days)

      expired_backups.find_each do |backup|
        begin
          delete_backup(backup)
          cleaned_count += 1
        rescue StandardError => e
          Rails.logger.error "[CleanupJob] Failed to delete backup #{backup.id}: #{e.message}"
          failed_count += 1
        end
      end
    end

    Rails.logger.info "[CleanupJob] Backups: #{cleaned_count} cleaned, #{failed_count} failed"

    { cleaned: cleaned_count, failed: failed_count }
  end

  def cleanup_old_health_checks
    Rails.logger.info "[CleanupJob] Starting health check cleanup (#{HEALTH_CHECK_RETENTION_DAYS} day retention)"

    deleted_count = HealthCheck.cleanup_old_records!(retention_days: HEALTH_CHECK_RETENTION_DAYS)

    Rails.logger.info "[CleanupJob] Health checks: #{deleted_count} deleted"

    deleted_count
  end

  private

  def delete_backup(backup)
    # Delete from all storage backends (primary + any extras from the backup job)
    if backup.file_path.present?
      backends = backup.backup_job&.effective_storage_backends || []
      backends << backup.storage_backend if backup.storage_backend.present?
      backends.uniq(&:id).each do |backend|
        backend.delete(backup.file_path) if backend.exists?(backup.file_path)
      rescue StandardError => e
        Rails.logger.warn "[CleanupJob] Failed to delete #{backup.file_name} from #{backend.name}: #{e.message}"
      end
    end

    # Delete record
    backup.destroy!

    AuditLog.log(
      action: "backup_cleaned",
      user: backup.user,
      details: {
        backup_id: backup.id,
        file_name: backup.file_name,
        reason: "retention_expired"
      }
    )
  end
end
