# frozen_string_literal: true

class RestoreExecutionJob
  include Sidekiq::Job
  include VpnConnectable

  sidekiq_options queue: :restores, retry: 2

  def perform(restore_id, options = {})
    restore = Restore.find(restore_id)
    target_config = restore.database_config

    Rails.logger.info "[RestoreExecutionJob] Starting restore #{restore_id} to #{target_config.database_name}"

    restore.update!(status: :running, started_at: Time.current)

    with_vpn_for(target_config) do
      # Merge encryption key from the backup's job so RestoreService can decrypt
      if restore.backup&.encrypted? && restore.backup.backup_job&.encryption_key.present?
        options = options.symbolize_keys.merge(encryption_key: restore.backup.backup_job.encryption_key)
      end

      # Determine the source - either from a backup or from uploaded file
      if restore.backup.present?
        service = RestoreService.new(
          backup: restore.backup,
          target_database_config: target_config,
          options: options.symbolize_keys
        )
      elsif restore.file_path.present?
        service = RestoreService.new(
          backup: OpenStruct.new(
            id: 0,
            file_path: restore.file_path,
            encrypted?: restore.file_path.end_with?(".enc"),
            compressed?: restore.file_path.end_with?(".gz") || restore.file_path.include?(".gz."),
            backup_job: OpenStruct.new(database_config: target_config),
            storage_backend: OpenStruct.new(
              exists?: ->(_) { File.exist?(restore.file_path) },
              retrieve: ->(_, dest) { FileUtils.cp(restore.file_path, dest); dest }
            )
          ),
          target_database_config: target_config,
          options: options.symbolize_keys
        )
      else
        raise "Restore has no backup or file path"
      end

      result = service.call
      raise result.error unless result.success?
    end

    restore.update!(status: :completed, completed_at: Time.current)

    AuditLog.log(
      action: "restore_completed",
      user: restore.user,
      resource: restore,
      details: {
        target_database: target_config.database_name,
        source_backup_id: restore.backup_id,
        source_file: restore.file_path
      }
    )

    # Send notification on success
    if restore.backup&.backup_job&.notification_channels&.any?
      NotificationJob.perform_async(
        restore.backup.backup_job.id,
        "restore_completed",
        {
          restore_id: restore.id,
          target_database: target_config.name
        }
      )
    end

    result
  rescue StandardError => e
    Rails.logger.error "[RestoreExecutionJob] Failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")

    if restore
      restore.update!(
        status: :failed,
        completed_at: Time.current,
        error_message: e.message
      )

      AuditLog.log(
        action: "restore_failed",
        user: restore.user,
        resource: restore,
        details: {
          target_database: restore.database_config&.database_name,
          error: e.message
        }
      )

      # Send notification on failure
      if restore.backup&.backup_job&.notification_channels&.any?
        NotificationJob.perform_async(
          restore.backup.backup_job.id,
          "restore_failed",
          {
            restore_id: restore.id,
            target_database: restore.database_config&.name,
            error: e.message
          }
        )
      end
    end

    raise
  end
end
