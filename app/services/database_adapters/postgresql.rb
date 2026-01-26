# frozen_string_literal: true

require "pg"
require "open3"

module DatabaseAdapters
  # PostgreSQL database adapter implementing all database operations
  # for PostgreSQL databases using pg gem and command-line tools.
  #
  # Usage:
  #   adapter = DatabaseAdapterFactory.for(database_config)
  #   adapter.test_connection
  #   adapter.backup(output_path: "/tmp/backup.dump", format: :custom)
  #
  class Postgresql < Base
    # =========================================================================
    # CONNECTION & HEALTH
    # =========================================================================

    # Test the database connection
    # @return [Hash] { success: Boolean, message: String, version: String, error: String }
    def test_connection
      conn = PG.connect(pg_connection_params)
      version = conn.exec("SELECT version()").first["version"]
      server_ver = version.match(/PostgreSQL (\d+\.\d+)/)[1] rescue nil

      {
        success: true,
        message: "Connected successfully",
        version: version,
        server_version: server_ver
      }
    rescue PG::Error => e
      { success: false, error: e.message }
    ensure
      conn&.close
    end

    # Get the database server version
    # @return [String] Version string (e.g., "16.1")
    def server_version
      conn = PG.connect(pg_connection_params)
      result = conn.exec("SHOW server_version")
      result.first["server_version"]
    rescue PG::Error => e
      nil
    ensure
      conn&.close
    end

    # =========================================================================
    # BACKUP & RESTORE
    # =========================================================================

    # Create a backup of the database using pg_dump
    # @param output_path [String] Path to write the backup file
    # @param format [Symbol] Backup format (:custom, :plain, :directory, :tar)
    # @param options [Hash] Additional options (verbose, tables, exclude_tables)
    # @return [Hash] { success: Boolean, file_path: String, file_size: Integer, error: String }
    def backup(output_path:, format: :custom, options: {})
      validate_pg_dump!

      env = { "PGPASSWORD" => config.password }
      cmd = build_pg_dump_command(output_path, format, options)

      result = execute_command(cmd, env: env, timeout: options[:timeout] || 3600)

      if result[:success]
        {
          success: true,
          file_path: output_path,
          file_size: File.size(output_path),
          format: format
        }
      else
        { success: false, error: result[:stderr] }
      end
    end

    # Restore a database from backup using pg_restore or psql
    # @param backup_path [String] Path to the backup file
    # @param options [Hash] Additional options (clean, no_owner, single_transaction)
    # @return [Hash] { success: Boolean, message: String, error: String }
    def restore(backup_path:, options: {})
      validate_pg_restore!
      validate_backup_file!(backup_path)

      env = { "PGPASSWORD" => config.password }

      result = if plain_sql_backup?(backup_path)
        execute_psql_restore(env, backup_path, options)
      else
        execute_pg_restore(env, backup_path, options)
      end

      if result[:success] || result[:exit_code] == 1
        # pg_restore returns 1 for non-fatal warnings
        { success: true, message: "Restore completed", warnings: result[:stderr] }
      else
        { success: false, error: result[:stderr] }
      end
    end

    # Get supported backup formats for PostgreSQL
    # @return [Array<Symbol>]
    def supported_backup_formats
      [:custom, :plain, :directory, :tar]
    end

    # =========================================================================
    # DATABASE INFORMATION
    # =========================================================================

    # Get the size of the database in bytes
    # @return [Integer] Size in bytes
    def database_size
      with_connection do |conn|
        result = conn.exec("SELECT pg_database_size(current_database()) as size")
        result.first["size"].to_i
      end
    end

    # List all databases on the server
    # @return [Array<Hash>] Database info with name, size, owner
    def list_databases
      with_connection do |conn|
        result = conn.exec(<<~SQL)
          SELECT
            datname as name,
            pg_database_size(datname) as size,
            pg_catalog.pg_get_userbyid(datdba) as owner,
            pg_catalog.pg_encoding_to_char(encoding) as encoding
          FROM pg_database
          WHERE datistemplate = false
          ORDER BY datname
        SQL
        result.map do |row|
          {
            name: row["name"],
            size: row["size"].to_i,
            owner: row["owner"],
            encoding: row["encoding"]
          }
        end
      end
    end

    # List all tables in the database with row counts and sizes
    # @return [Array<Hash>] Table info with name, row_count, size
    def list_tables
      with_connection do |conn|
        result = conn.exec(<<~SQL)
          SELECT
            schemaname as schema,
            relname as name,
            n_live_tup as row_count,
            pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(relname)) as total_size,
            pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(relname)) as table_size
          FROM pg_stat_user_tables
          ORDER BY schemaname, relname
        SQL
        result.map do |row|
          {
            schema: row["schema"],
            name: row["name"],
            row_count: row["row_count"].to_i,
            total_size: row["total_size"].to_i,
            table_size: row["table_size"].to_i
          }
        end
      end
    end

    # =========================================================================
    # STATISTICS & MONITORING
    # =========================================================================

    # Get detailed table statistics
    # @return [Array<Hash>] Stats for each table
    def table_statistics
      with_connection do |conn|
        result = conn.exec(<<~SQL)
          SELECT
            schemaname as schema,
            relname as name,
            n_live_tup as live_tuples,
            n_dead_tup as dead_tuples,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins as inserts,
            n_tup_upd as updates,
            n_tup_del as deletes,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze,
            vacuum_count,
            autovacuum_count
          FROM pg_stat_user_tables
          ORDER BY schemaname, relname
        SQL
        result.map { |row| symbolize_row(row) }
      end
    end

    # Get connection/session statistics
    # @return [Hash] Connection stats (active, idle, max, etc.)
    def connection_statistics
      with_connection do |conn|
        result = conn.exec(<<~SQL)
          SELECT
            count(*) FILTER (WHERE state = 'active') as active,
            count(*) FILTER (WHERE state = 'idle') as idle,
            count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_transaction,
            count(*) FILTER (WHERE state = 'idle in transaction (aborted)') as idle_in_transaction_aborted,
            count(*) FILTER (WHERE wait_event_type IS NOT NULL AND state = 'active') as waiting,
            count(*) as total,
            current_setting('max_connections')::int as max_connections
          FROM pg_stat_activity
          WHERE datname = current_database()
        SQL
        row = result.first
        {
          active: row["active"].to_i,
          idle: row["idle"].to_i,
          idle_in_transaction: row["idle_in_transaction"].to_i,
          idle_in_transaction_aborted: row["idle_in_transaction_aborted"].to_i,
          waiting: row["waiting"].to_i,
          total: row["total"].to_i,
          max_connections: row["max_connections"].to_i
        }
      end
    end

    # Get overall database health metrics
    # @return [Hash] Health metrics
    def health_metrics
      with_connection do |conn|
        result = conn.exec(<<~SQL)
          WITH cache_stats AS (
            SELECT
              COALESCE(sum(heap_blks_read), 0) as heap_read,
              COALESCE(sum(heap_blks_hit), 0) as heap_hit,
              COALESCE(sum(idx_blks_read), 0) as idx_read,
              COALESCE(sum(idx_blks_hit), 0) as idx_hit
            FROM pg_statio_user_tables
          ),
          db_stats AS (
            SELECT deadlocks, xact_commit, xact_rollback, temp_files, temp_bytes
            FROM pg_stat_database
            WHERE datname = current_database()
          ),
          xid_stats AS (
            SELECT
              age(datfrozenxid) as xid_age,
              current_setting('autovacuum_freeze_max_age')::bigint as freeze_max_age
            FROM pg_database
            WHERE datname = current_database()
          ),
          table_stats AS (
            SELECT
              COALESCE(sum(n_dead_tup), 0) as dead_tuples,
              max(COALESCE(last_vacuum, last_autovacuum)) as last_vacuum,
              max(COALESCE(last_analyze, last_autoanalyze)) as last_analyze
            FROM pg_stat_user_tables
          )
          SELECT
            cs.heap_read, cs.heap_hit, cs.idx_read, cs.idx_hit,
            ds.deadlocks, ds.xact_commit, ds.xact_rollback, ds.temp_files, ds.temp_bytes,
            xs.xid_age, xs.freeze_max_age,
            ts.dead_tuples, ts.last_vacuum, ts.last_analyze,
            pg_postmaster_start_time() as server_start_time
          FROM cache_stats cs
          CROSS JOIN db_stats ds
          CROSS JOIN xid_stats xs
          CROSS JOIN table_stats ts
        SQL
        row = result.first

        # Calculate cache hit ratio
        total_read = row["heap_read"].to_i + row["idx_read"].to_i
        total_hit = row["heap_hit"].to_i + row["idx_hit"].to_i
        cache_hit_ratio = if (total_read + total_hit) > 0
          ((total_hit.to_f / (total_read + total_hit)) * 100).round(2)
        else
          100.0
        end

        {
          cache_hit_ratio: cache_hit_ratio,
          deadlocks: row["deadlocks"].to_i,
          commits: row["xact_commit"].to_i,
          rollbacks: row["xact_rollback"].to_i,
          temp_files: row["temp_files"].to_i,
          temp_bytes: row["temp_bytes"].to_i,
          xid_age: row["xid_age"].to_i,
          freeze_max_age: row["freeze_max_age"].to_i,
          dead_tuples: row["dead_tuples"].to_i,
          last_vacuum: row["last_vacuum"],
          last_analyze: row["last_analyze"],
          server_start_time: row["server_start_time"]
        }
      end
    end

    # =========================================================================
    # MAINTENANCE OPERATIONS
    # =========================================================================

    # Run VACUUM ANALYZE on the database
    # @return [Hash] { success: Boolean, error: String }
    def vacuum_analyze
      with_connection do |conn|
        conn.exec("VACUUM ANALYZE")
        { success: true }
      end
    rescue PG::Error => e
      { success: false, error: e.message }
    end

    # Terminate active connections to the database
    # @param database_name [String] Name of database (defaults to configured database)
    # @return [Hash] { success: Boolean, terminated_count: Integer }
    def terminate_connections(database_name = nil)
      db_name = database_name || config.database_name
      with_connection do |conn|
        result = conn.exec_params(<<~SQL, [db_name])
          SELECT pg_terminate_backend(pid)
          FROM pg_stat_activity
          WHERE datname = $1
            AND pid <> pg_backend_pid()
            AND state != 'idle'
        SQL
        { success: true, terminated_count: result.ntuples }
      end
    rescue PG::Error => e
      { success: false, error: e.message, terminated_count: 0 }
    end

    # Terminate a specific backend by PID
    # @param pid [Integer] Process ID to terminate
    # @return [Hash] { success: Boolean, terminated: Boolean }
    def terminate_backend(pid)
      with_connection do |conn|
        result = conn.exec_params("SELECT pg_terminate_backend($1)", [pid])
        terminated = result.first["pg_terminate_backend"] == "t"
        { success: true, terminated: terminated }
      end
    rescue PG::Error => e
      { success: false, error: e.message }
    end

    # Get long-running queries
    # @param min_duration_seconds [Integer] Minimum duration threshold
    # @return [Array<Hash>] List of long-running queries
    def long_running_queries(min_duration_seconds = 300)
      with_connection do |conn|
        result = conn.exec_params(<<~SQL, [min_duration_seconds])
          SELECT
            pid,
            usename as username,
            state,
            query,
            EXTRACT(EPOCH FROM (now() - query_start))::integer as duration_seconds,
            query_start,
            wait_event_type,
            wait_event
          FROM pg_stat_activity
          WHERE datname = current_database()
            AND state != 'idle'
            AND query NOT ILIKE '%pg_stat_activity%'
            AND EXTRACT(EPOCH FROM (now() - query_start)) > $1
          ORDER BY query_start ASC
        SQL
        result.map { |row| symbolize_row(row) }
      end
    rescue PG::Error
      []
    end

    # =========================================================================
    # UTILITY METHODS
    # =========================================================================

    # List of features supported by PostgreSQL adapter
    # @return [Array<Symbol>]
    def supported_features
      [:vacuum, :analyze, :vacuum_analyze, :terminate_backend, :replication, :streaming_backup]
    end

    protected

    # Build PostgreSQL connection string for command-line tools
    # @return [String]
    def connection_string
      "postgresql://#{config.username}:***@#{config.host}:#{config.port}/#{config.database_name}"
    end

    private

    # Connection parameters formatted for PG gem
    # @return [Hash]
    def pg_connection_params
      params = {
        host: config.host,
        port: config.port,
        dbname: config.database_name,
        user: config.username,
        password: config.password
      }
      params[:sslmode] = config.ssl_mode if config.respond_to?(:ssl_mode) && config.ssl_mode.present?
      params.compact
    end

    # Execute block with a managed connection
    # @yield [PG::Connection]
    # @return [Object] Block return value
    def with_connection
      conn = PG.connect(pg_connection_params)
      yield conn
    rescue PG::Error => e
      { error: e.message }
    ensure
      conn&.close
    end

    # Convert PG::Result row to symbolized hash
    # @param row [Hash] Row from PG::Result
    # @return [Hash]
    def symbolize_row(row)
      row.transform_keys(&:to_sym).transform_values do |v|
        case v
        when /^\d+$/ then v.to_i
        else v
        end
      end
    end

    # =========================================================================
    # BACKUP HELPERS
    # =========================================================================

    def validate_pg_dump!
      unless system("which pg_dump > /dev/null 2>&1")
        raise "pg_dump not found in PATH"
      end
    end

    def validate_pg_restore!
      unless system("which pg_restore > /dev/null 2>&1")
        raise "pg_restore not found in PATH"
      end
    end

    def validate_backup_file!(path)
      raise "Backup file not found: #{path}" unless File.exist?(path)
    end

    def build_pg_dump_command(output_path, format, options)
      cmd = ["pg_dump"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--username=#{config.username}"
      cmd << "--format=#{pg_dump_format(format)}"
      cmd << "--file=#{output_path}"
      cmd << "--verbose" if options[:verbose]

      # Table filtering
      Array(options[:tables]).each { |t| cmd << "--table=#{t}" }
      Array(options[:exclude_tables]).each { |t| cmd << "--exclude-table=#{t}" }

      # Schema filtering
      Array(options[:schemas]).each { |s| cmd << "--schema=#{s}" }
      Array(options[:exclude_schemas]).each { |s| cmd << "--exclude-schema=#{s}" }

      cmd << config.database_name
      cmd.join(" ")
    end

    def pg_dump_format(format)
      case format.to_sym
      when :plain then "p"
      when :custom then "c"
      when :directory then "d"
      when :tar then "t"
      else "c"
      end
    end

    # Check if backup file is plain SQL (not custom format)
    # Custom format starts with "PGDMP"
    def plain_sql_backup?(file_path)
      File.open(file_path, "rb") do |f|
        header = f.read(5)
        header != "PGDMP"
      end
    end

    def execute_pg_restore(env, backup_path, options)
      cmd = build_pg_restore_command(backup_path, options)
      execute_command(cmd, env: env, timeout: options[:timeout] || 3600)
    end

    def execute_psql_restore(env, backup_path, options)
      cmd = build_psql_command(backup_path, options)
      execute_command(cmd, env: env, timeout: options[:timeout] || 3600)
    end

    def build_pg_restore_command(backup_path, options)
      cmd = ["pg_restore"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--username=#{config.username}"
      cmd << "--dbname=#{config.database_name}"
      cmd << "--clean" if options.fetch(:clean, true)
      cmd << "--if-exists" if options.fetch(:if_exists, true)
      cmd << "--no-owner" if options.fetch(:no_owner, true)
      cmd << "--no-privileges" if options.fetch(:no_privileges, true)
      cmd << "--single-transaction" if options.fetch(:single_transaction, true)
      cmd << "--verbose" if options[:verbose]
      cmd << backup_path
      cmd.join(" ")
    end

    def build_psql_command(backup_path, options)
      cmd = ["psql"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--username=#{config.username}"
      cmd << "--dbname=#{config.database_name}"
      cmd << "--single-transaction" if options.fetch(:single_transaction, true)
      cmd << "--file=#{backup_path}"
      cmd.join(" ")
    end
  end
end

# Register PostgreSQL adapter with the factory
DatabaseAdapterFactory.register(:postgresql, DatabaseAdapters::Postgresql)
DatabaseAdapterFactory.register(:postgres, DatabaseAdapters::Postgresql)
