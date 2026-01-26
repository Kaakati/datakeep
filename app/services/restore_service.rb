# frozen_string_literal: true

# Unified restore service that works with any database type through the adapter pattern.
#
# This service handles the full restore workflow:
# 1. Downloads backup from storage backend
# 2. Optionally decrypts the backup
# 3. Optionally decompresses the backup
# 4. Restores to target database via adapter (pg_restore, mysql, etc.)
#
# Usage:
#   result = RestoreService.new(
#     backup: backup_record,
#     target_database_config: config,
#     options: { clean: true, no_owner: true }
#   ).call
#
#   if result.success?
#     puts "Restore completed successfully"
#   else
#     puts "Restore failed: #{result.error}"
#   end
#
class RestoreService
  class RestoreError < StandardError; end

  attr_reader :backup, :target_database_config, :options

  def initialize(backup:, target_database_config:, options: {})
    @backup = backup
    @target_database_config = target_database_config
    @options = default_options.merge(options)
  end

  def call
    validate!

    temp_file = download_backup
    begin
      decrypt_if_needed(temp_file)
      decompress_if_needed(temp_file)
      restore_result = run_restore(temp_file)

      Result.success(**restore_result)
    rescue StandardError => e
      Result.failure(error: e.message)
    ensure
      cleanup_temp_files(temp_file)
    end
  end

  private

  def default_options
    {
      clean: true,
      if_exists: true,
      no_owner: true,
      no_privileges: true,
      single_transaction: true,
      verbose: false,
      timeout: 3600
    }
  end

  def validate!
    raise RestoreError, "Backup is required" unless backup
    raise RestoreError, "Target database config is required" unless target_database_config
    raise RestoreError, "Backup file not found" unless backup_file_exists?

    # Validate database types are compatible
    validate_database_compatibility!
  end

  def validate_database_compatibility!
    backup_type = backup.backup_job&.database_config&.database_type || "postgresql"
    target_type = target_database_config.database_type || "postgresql"

    unless backup_type == target_type
      raise RestoreError, "Cannot restore #{backup_type} backup to #{target_type} database"
    end
  end

  def backup_file_exists?
    backup.storage_backend.exists?(backup.file_path)
  end

  def adapter
    @adapter ||= DatabaseAdapterFactory.for(target_database_config)
  end

  def download_backup
    temp_file = File.join(Dir.tmpdir, "datakeeper_restore_#{backup.id}_#{Time.current.to_i}")

    Rails.logger.info "[RestoreService] Downloading backup #{backup.id} from storage"
    backup.storage_backend.retrieve(backup.file_path, temp_file)

    temp_file
  end

  def decrypt_if_needed(file_path)
    return file_path unless backup.encrypted?
    return file_path unless options[:encryption_key]

    Rails.logger.info "[RestoreService] Decrypting backup"
    decrypted_path = "#{file_path}.decrypted"
    EncryptionService.decrypt_file(file_path, decrypted_path, options[:encryption_key])

    File.delete(file_path)
    File.rename(decrypted_path, file_path)

    file_path
  end

  def decompress_if_needed(file_path)
    return file_path unless backup.compressed?
    return file_path unless needs_decompression?(file_path)

    Rails.logger.info "[RestoreService] Decompressing backup"
    decompressed_path = "#{file_path}.decompressed"

    Zlib::GzipReader.open(file_path) do |gz|
      File.open(decompressed_path, "wb") do |f|
        while (chunk = gz.read(1024 * 1024))
          f.write(chunk)
        end
      end
    end

    File.delete(file_path)
    File.rename(decompressed_path, file_path)

    file_path
  end

  def needs_decompression?(file_path)
    # Check if file is actually gzip compressed by reading magic bytes
    File.open(file_path, "rb") do |f|
      header = f.read(2)
      header == "\x1f\x8b" # Gzip magic bytes
    end
  rescue
    false
  end

  def run_restore(file_path)
    Rails.logger.info "[RestoreService] Restoring to #{target_database_config.database_name} (#{target_database_config.database_type})"

    result = adapter.restore(
      backup_path: file_path,
      options: {
        clean: options[:clean],
        if_exists: options[:if_exists],
        no_owner: options[:no_owner],
        no_privileges: options[:no_privileges],
        single_transaction: options[:single_transaction],
        verbose: options[:verbose],
        timeout: options[:timeout]
      }
    )

    raise RestoreError, result[:error] unless result[:success]

    {
      message: result[:message] || "Restore completed successfully",
      warnings: result[:warnings],
      target_database: target_database_config.database_name,
      backup_id: backup.id
    }
  end

  def cleanup_temp_files(temp_file)
    return unless temp_file

    [
      temp_file,
      "#{temp_file}.decrypted",
      "#{temp_file}.decompressed"
    ].each do |path|
      File.delete(path) if File.exist?(path)
    rescue StandardError
      # Ignore cleanup errors
    end
  end

  # Result object for service responses
  class Result
    attr_reader :data, :error

    def initialize(success:, data: {}, error: nil)
      @success = success
      @data = data
      @error = error
    end

    def self.success(**data)
      new(success: true, data: data)
    end

    def self.failure(error:, **data)
      new(success: false, error: error, data: data)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end

    def method_missing(method_name, *args)
      return @data[method_name] if @data.key?(method_name)
      super
    end

    def respond_to_missing?(method_name, include_private = false)
      @data.key?(method_name) || super
    end
  end
end
