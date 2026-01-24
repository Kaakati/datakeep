# frozen_string_literal: true

class PostgresBackupService
  class BackupError < StandardError; end

  attr_reader :database_config, :storage_backend, :options

  def initialize(database_config:, storage_backend:, options: {})
    @database_config = database_config
    @storage_backend = storage_backend
    @options = default_options.merge(options)
  end

  def execute
    validate!

    temp_file = generate_temp_path
    begin
      run_pg_dump(temp_file)
      compress_if_needed(temp_file)
      encrypt_if_needed(temp_file)
      upload_to_storage(temp_file)
    ensure
      cleanup_temp_files(temp_file)
    end
  end

  private

  def default_options
    {
      compression: true,
      encryption: false,
      format: "custom",  # custom, plain, directory, tar
      verbose: false
    }
  end

  def validate!
    raise BackupError, "Database config is required" unless database_config
    raise BackupError, "Storage backend is required" unless storage_backend
    raise BackupError, "pg_dump not found" unless pg_dump_available?
  end

  def pg_dump_available?
    system("which pg_dump > /dev/null 2>&1")
  end

  def generate_temp_path
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    File.join(Dir.tmpdir, "dbops_backup_#{database_config.id}_#{timestamp}.dump")
  end

  def generate_file_name
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    extension = backup_extension
    "#{database_config.database_name}_#{timestamp}#{extension}"
  end

  def backup_extension
    ext = case options[:format]
    when "plain" then ".sql"
    when "custom" then ".dump"
    when "directory" then ""
    when "tar" then ".tar"
    else ".dump"
    end

    # Only add .gz for formats that we actually gzip (custom format has built-in compression)
    ext += ".gz" if options[:compression] && options[:format] != "custom"
    ext += ".enc" if options[:encryption]
    ext
  end

  def run_pg_dump(output_path)
    env = build_env
    cmd = build_pg_dump_command(output_path)

    Rails.logger.info "[PostgresBackupService] Running pg_dump for #{database_config.database_name}"

    stdout, stderr, status = Open3.capture3(env, cmd)

    unless status.success?
      raise BackupError, "pg_dump failed: #{stderr}"
    end

    output_path
  end

  def build_env
    {
      "PGPASSWORD" => database_config.password
    }
  end

  def build_pg_dump_command(output_path)
    cmd = [ "pg_dump" ]
    cmd << "--host=#{database_config.host}"
    cmd << "--port=#{database_config.port}"
    cmd << "--username=#{database_config.username}"
    cmd << "--format=#{pg_dump_format}"
    cmd << "--file=#{output_path}"
    cmd << "--verbose" if options[:verbose]
    cmd << database_config.database_name

    cmd.join(" ")
  end

  def pg_dump_format
    case options[:format]
    when "plain" then "p"
    when "custom" then "c"
    when "directory" then "d"
    when "tar" then "t"
    else "c"
    end
  end

  def compress_if_needed(file_path)
    return file_path unless options[:compression]
    return file_path if options[:format] == "custom"  # Already compressed

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
      encrypted: options[:encryption]
    }
  end

  def cleanup_temp_files(temp_file)
    [
      temp_file,
      "#{temp_file}.gz",
      "#{temp_file}.enc"
    ].each do |path|
      File.delete(path) if File.exist?(path)
    end
  end
end
