# frozen_string_literal: true

# Syncs data from one source database to multiple target databases.
#
# Uses the existing adapter pattern (pg_dump → pg_restore) to perform
# a full database copy from source to each target on every sync run.
#
# Usage:
#   result = SyncService.call(sync_job)
#   result.succeeded  # => 2
#   result.failed     # => 0
#
class SyncService
  class SyncError < StandardError; end

  Result = Struct.new(:succeeded, :failed, :errors, keyword_init: true)

  def self.call(sync_job)
    new(sync_job).perform
  end

  def initialize(sync_job)
    @sync_job = sync_job
  end

  def perform
    validate!

    tmp_path = generate_temp_path
    errors = []
    succeeded = 0

    begin
      # Wrap source dump with VPN if the source database is behind a VPN
      Vpn::ConnectionFactory.with_connection_for(@sync_job.source_database_config) do
        dump_source(tmp_path)
      end

      @sync_job.target_database_configs.each do |target|
        # Wrap each target restore with its own VPN connection
        Vpn::ConnectionFactory.with_connection_for(target) do
          restore_to_target(tmp_path, target)
        end
        succeeded += 1
        Rails.logger.info "[SyncService] Synced to #{target.name} successfully"
      rescue StandardError => e
        Rails.logger.error "[SyncService] Failed to sync to #{target.name}: #{e.message}"
        errors << { target: target.name, error: e.message }
      end
    ensure
      FileUtils.rm_f(tmp_path) if tmp_path && File.exist?(tmp_path)
    end

    Result.new(
      succeeded: succeeded,
      failed: errors.size,
      errors: errors
    )
  end

  private

  def validate!
    raise SyncError, "No target databases configured" if @sync_job.target_database_configs.empty?
  end

  def generate_temp_path
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    File.join(Dir.tmpdir, "datakeep_sync_#{@sync_job.id}_#{timestamp}.dump")
  end

  def dump_source(output_path)
    source_adapter = DatabaseAdapterFactory.for(@sync_job.source_database_config)
    result = source_adapter.backup(output_path: output_path, format: :custom)
    raise SyncError, "Source dump failed: #{result[:error]}" unless result[:success]

    Rails.logger.info "[SyncService] Dumped #{@sync_job.source_database_config.name} to #{output_path}"
  end

  def restore_to_target(dump_path, target_config)
    target_adapter = DatabaseAdapterFactory.for(target_config)
    result = target_adapter.restore(
      backup_path: dump_path,
      options: { clean: true, no_owner: true, no_privileges: true }
    )
    raise SyncError, "Restore to #{target_config.name} failed: #{result[:error]}" unless result[:success]
  end
end
