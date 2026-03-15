# frozen_string_literal: true

# Unified backup service that works with any database type through the adapter pattern.
#
# This service handles the full backup workflow:
# 1. Creates backup via database adapter (pg_dump, mysqldump, etc.)
# 2. Optionally compresses the backup
# 3. Optionally encrypts the backup
# 4. Uploads to the configured storage backend
#
# Usage:
#   result = BackupService.new(
#     database_config: config,
#     storage_backend: backend,
#     options: { compression: true, format: :custom }
#   ).call
#
#   if result.success?
#     puts "Backup saved to: #{result.file_path}"
#   else
#     puts "Backup failed: #{result.error}"
#   end
#
class BackupService
  class BackupError < StandardError; end

  attr_reader :database_config, :storage_backend, :options

  def initialize(database_config:, storage_backend: nil, options: {})
    @database_config = database_config
    @storage_backend = storage_backend
    @options = default_options.merge(options)
  end

  def call
    validate!

    temp_file = generate_temp_path
    begin
      run_backup(temp_file)
      compress_if_needed(temp_file)
      encrypt_if_needed(temp_file)
      upload_result = upload_to_storage(temp_file)

      Result.success(**upload_result)
    rescue StandardError => e
      Result.failure(error: e.message)
    ensure
      cleanup_temp_files(temp_file)
    end
  end

  # Runs the dump phase only (backup + compress + encrypt) without uploading.
  # Returns a DumpResult with the temp file path and metadata.
  # Caller is responsible for cleanup via cleanup_temp_files.
  def dump
    raise BackupError, "Database config is required" unless database_config

    temp_file = generate_temp_path
    run_backup(temp_file)
    compress_if_needed(temp_file)
    encrypt_if_needed(temp_file)

    file_name = generate_file_name
    file_size = File.size(temp_file)
    checksum = Digest::SHA256.file(temp_file).hexdigest

    DumpResult.new(
      temp_file: temp_file,
      file_name: file_name,
      file_size: file_size,
      checksum: checksum
    )
  end

  # Uploads a temp file to a single storage backend.
  def self.upload(storage_backend:, temp_file:, file_name:)
    stored_path = storage_backend.store(temp_file, file_name)
    { success: true, file_path: stored_path }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  DumpResult = Struct.new(:temp_file, :file_name, :file_size, :checksum, keyword_init: true)

  private

  def default_options
    {
      compression: true,
      encryption: false,
      format: :custom,
      verbose: false,
      timeout: 3600
    }
  end

  def validate!
    raise BackupError, "Database config is required" unless database_config
    raise BackupError, "Storage backend is required" unless storage_backend
  end

  def adapter
    @adapter ||= DatabaseAdapterFactory.for(database_config)
  end

  def generate_temp_path
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    File.join(Dir.tmpdir, "datakeeper_backup_#{database_config.id}_#{timestamp}.dump")
  end

  def generate_file_name
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    db_type = database_config.database_type || "db"
    extension = backup_extension
    "#{database_config.database_name}_#{db_type}_#{timestamp}#{extension}"
  end

  def backup_extension
    db_type = database_config.database_type || "postgresql"

    ext = case db_type
    when "mongodb"
      ".archive"
    when "mysql"
      ".sql"
    else # postgresql
      case options[:format].to_sym
      when :plain then ".sql"
      when :custom then ".dump"
      when :directory then ""
      when :tar then ".tar"
      else ".dump"
      end
    end

    # Only add .gz for formats that need external compression
    if options[:compression] && needs_external_compression?
      ext += ".gz"
    end

    ext += ".enc" if options[:encryption]
    ext
  end

  def needs_external_compression?
    db_type = database_config.database_type || "postgresql"

    # PostgreSQL custom format has built-in compression
    return false if db_type == "postgresql" && options[:format].to_sym == :custom
    # MongoDB's mongodump --gzip handles compression natively
    return false if db_type == "mongodb"
    true
  end

  def run_backup(output_path)
    Rails.logger.info "[BackupService] Running backup for #{database_config.database_name} (#{database_config.database_type})"

    result = adapter.backup(
      output_path: output_path,
      format: options[:format],
      options: {
        verbose: options[:verbose],
        timeout: options[:timeout],
        tables: options[:tables],
        exclude_tables: options[:exclude_tables]
      }
    )

    raise BackupError, result[:error] unless result[:success]

    output_path
  end

  def compress_if_needed(file_path)
    return file_path unless options[:compression]
    return file_path unless needs_external_compression?

    compressed_path = "#{file_path}.gz"

    Zlib::GzipWriter.open(compressed_path) do |gz|
      File.open(file_path, "rb") do |f|
        while (chunk = f.read(1024 * 1024))
          gz.write(chunk)
        end
      end
    end

    File.delete(file_path)
    File.rename(compressed_path, file_path)

    file_path
  end

  def encrypt_if_needed(file_path)
    return file_path unless options[:encryption]
    return file_path unless options[:encryption_key]

    encrypted_path = "#{file_path}.enc"
    EncryptionService.encrypt_file(file_path, encrypted_path, options[:encryption_key])

    File.delete(file_path)
    File.rename(encrypted_path, file_path)

    file_path
  end

  def upload_to_storage(temp_file)
    file_name = generate_file_name
    stored_path = storage_backend.store(temp_file, file_name)
    file_size = File.size(temp_file)
    checksum = Digest::SHA256.file(temp_file).hexdigest

    {
      file_path: stored_path,
      file_name: file_name,
      file_size: file_size,
      checksum: checksum,
      compressed: options[:compression],
      encrypted: options[:encryption],
      format: options[:format],
      database_type: database_config.database_type
    }
  end

  def cleanup_temp_files(temp_file)
    return unless temp_file

    [
      temp_file,
      "#{temp_file}.gz",
      "#{temp_file}.enc"
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
