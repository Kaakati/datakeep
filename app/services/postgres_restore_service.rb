# frozen_string_literal: true

class PostgresRestoreService
  class RestoreError < StandardError; end

  attr_reader :backup, :target_database_config, :options

  def initialize(backup:, target_database_config:, options: {})
    @backup = backup
    @target_database_config = target_database_config
    @options = default_options.merge(options)
  end

  def execute
    validate!

    temp_file = download_backup
    begin
      decrypt_if_needed(temp_file)
      decompress_if_needed(temp_file)
      run_restore(temp_file)
    ensure
      cleanup_temp_files(temp_file)
    end
  end

  private

  def default_options
    {
      clean: true,           # Drop database objects before recreating
      if_exists: true,       # Use IF EXISTS when dropping objects
      no_owner: true,        # Don't output commands to set ownership
      no_privileges: true,   # Don't output commands to grant/revoke privileges
      single_transaction: true
    }
  end

  def validate!
    raise RestoreError, "Backup is required" unless backup
    raise RestoreError, "Target database config is required" unless target_database_config
    raise RestoreError, "Backup file not found" unless backup.storage_backend.exists?(backup.file_path)
    raise RestoreError, "pg_restore not found" unless pg_restore_available?
  end

  def pg_restore_available?
    system("which pg_restore > /dev/null 2>&1")
  end

  def download_backup
    temp_file = File.join(Dir.tmpdir, "dbops_restore_#{backup.id}_#{Time.current.to_i}")
    backup.storage_backend.retrieve(backup.file_path, temp_file)
    temp_file
  end

  def decrypt_if_needed(file_path)
    return file_path unless backup.encrypted?

    decrypted_path = file_path.sub(/\.enc$/, "")
    EncryptionService.decrypt_file(file_path, decrypted_path, options[:encryption_key])

    File.delete(file_path)
    File.rename(decrypted_path, file_path)

    file_path
  end

  def decompress_if_needed(file_path)
    return file_path unless backup.compressed? && file_path.end_with?(".gz")

    decompressed_path = file_path.sub(/\.gz$/, "")

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

  def run_restore(file_path)
    env = build_env

    # Determine if we need pg_restore (for custom/tar format) or psql (for plain SQL)
    if plain_sql_backup?(file_path)
      run_psql_restore(env, file_path)
    else
      run_pg_restore(env, file_path)
    end
  end

  def plain_sql_backup?(file_path)
    # Check file header to determine format
    File.open(file_path, "rb") do |f|
      header = f.read(5)
      # Custom format starts with "PGDMP"
      header != "PGDMP"
    end
  end

  def build_env
    {
      "PGPASSWORD" => target_database_config.password
    }
  end

  def run_pg_restore(env, file_path)
    cmd = build_pg_restore_command(file_path)

    Rails.logger.info "[PostgresRestoreService] Running pg_restore to #{target_database_config.database_name}"

    stdout, stderr, status = Open3.capture3(env, cmd)

    # pg_restore may return non-zero even on success if some objects don't exist
    # We check for critical errors instead
    if status.exitstatus && status.exitstatus > 1
      raise RestoreError, "pg_restore failed: #{stderr}"
    end

    { success: true, output: stdout, warnings: stderr }
  end

  def run_psql_restore(env, file_path)
    cmd = build_psql_command(file_path)

    Rails.logger.info "[PostgresRestoreService] Running psql restore to #{target_database_config.database_name}"

    stdout, stderr, status = Open3.capture3(env, cmd)

    unless status.success?
      raise RestoreError, "psql restore failed: #{stderr}"
    end

    { success: true, output: stdout, warnings: stderr }
  end

  def build_pg_restore_command(file_path)
    cmd = [ "pg_restore" ]
    cmd << "--host=#{target_database_config.host}"
    cmd << "--port=#{target_database_config.port}"
    cmd << "--username=#{target_database_config.username}"
    cmd << "--dbname=#{target_database_config.database_name}"
    cmd << "--clean" if options[:clean]
    cmd << "--if-exists" if options[:if_exists]
    cmd << "--no-owner" if options[:no_owner]
    cmd << "--no-privileges" if options[:no_privileges]
    cmd << "--single-transaction" if options[:single_transaction]
    cmd << "--verbose" if options[:verbose]
    cmd << file_path

    cmd.join(" ")
  end

  def build_psql_command(file_path)
    cmd = [ "psql" ]
    cmd << "--host=#{target_database_config.host}"
    cmd << "--port=#{target_database_config.port}"
    cmd << "--username=#{target_database_config.username}"
    cmd << "--dbname=#{target_database_config.database_name}"
    cmd << "--single-transaction" if options[:single_transaction]
    cmd << "--file=#{file_path}"

    cmd.join(" ")
  end

  def cleanup_temp_files(temp_file)
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
end
