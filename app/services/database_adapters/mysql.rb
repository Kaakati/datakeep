# frozen_string_literal: true

require "mysql2"
require "open3"

module DatabaseAdapters
  # MySQL database adapter implementing all database operations
  # for MySQL databases using mysql2 gem and command-line tools (mysqldump, mysql).
  #
  # Usage:
  #   adapter = DatabaseAdapterFactory.for(database_config)
  #   adapter.test_connection
  #   adapter.backup(output_path: "/tmp/backup.sql", format: :sql)
  #
  class Mysql < Base
    # =========================================================================
    # CONNECTION & HEALTH
    # =========================================================================

    def test_connection
      client = mysql_client
      result = client.query("SELECT VERSION() AS version")
      version = result.first["version"]

      {
        success: true,
        message: "Connected successfully",
        version: "MySQL #{version}",
        server_version: version
      }
    rescue Mysql2::Error => e
      { success: false, error: e.message }
    ensure
      client&.close
    end

    def server_version
      client = mysql_client
      result = client.query("SELECT VERSION() AS version")
      result.first["version"]
    rescue Mysql2::Error
      nil
    ensure
      client&.close
    end

    # =========================================================================
    # BACKUP & RESTORE
    # =========================================================================

    def backup(output_path:, format: :sql, options: {})
      validate_mysqldump!

      env = build_mysql_env
      cmd = build_mysqldump_command(output_path, options)

      result = execute_command(cmd, env: env, timeout: options[:timeout] || 3600)

      if result[:success]
        {
          success: true,
          file_path: output_path,
          file_size: File.size(output_path),
          format: :sql
        }
      else
        { success: false, error: result[:stderr] }
      end
    end

    def restore(backup_path:, options: {})
      validate_mysql_client!
      validate_backup_file!(backup_path)

      env = build_mysql_env
      cmd = build_mysql_restore_command(backup_path, options)

      result = execute_command(cmd, env: env, timeout: options[:timeout] || 3600)

      if result[:success]
        { success: true, message: "Restore completed", warnings: result[:stderr] }
      else
        { success: false, error: result[:stderr] }
      end
    end

    def supported_backup_formats
      [:sql]
    end

    # =========================================================================
    # DATABASE INFORMATION
    # =========================================================================

    def database_size
      with_connection do |client|
        result = client.query(<<~SQL)
          SELECT SUM(data_length + index_length) AS size
          FROM information_schema.tables
          WHERE table_schema = DATABASE()
        SQL
        result.first["size"].to_i
      end
    end

    def list_databases
      with_connection do |client|
        result = client.query("SHOW DATABASES")
        result.map do |row|
          { name: row["Database"], size: nil, owner: nil, encoding: nil }
        end
      end
    end

    def list_tables
      with_connection do |client|
        result = client.query(<<~SQL)
          SELECT
            table_name AS name,
            table_rows AS row_count,
            data_length + index_length AS total_size,
            data_length AS table_size,
            engine
          FROM information_schema.tables
          WHERE table_schema = DATABASE()
            AND table_type = 'BASE TABLE'
          ORDER BY table_name
        SQL
        result.map do |row|
          {
            schema: nil,
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

    def table_statistics
      with_connection do |client|
        result = client.query(<<~SQL)
          SELECT
            table_name AS name,
            table_rows AS row_count,
            data_length,
            index_length,
            data_length + index_length AS total_size,
            engine,
            create_time,
            update_time
          FROM information_schema.tables
          WHERE table_schema = DATABASE()
            AND table_type = 'BASE TABLE'
          ORDER BY table_name
        SQL
        result.map do |row|
          {
            name: row["name"],
            row_count: row["row_count"].to_i,
            data_length: row["data_length"].to_i,
            index_length: row["index_length"].to_i,
            total_size: row["total_size"].to_i,
            engine: row["engine"],
            create_time: row["create_time"],
            update_time: row["update_time"]
          }
        end
      end
    end

    def connection_statistics
      with_connection do |client|
        threads = client.query("SHOW STATUS LIKE 'Threads_%'")
        max_conn = client.query("SHOW VARIABLES LIKE 'max_connections'")

        stats = {}
        threads.each { |row| stats[row["Variable_name"]] = row["Value"].to_i }
        max = max_conn.first

        {
          active: stats["Threads_running"] || 0,
          idle: (stats["Threads_connected"] || 0) - (stats["Threads_running"] || 0),
          total: stats["Threads_connected"] || 0,
          max_connections: max ? max["Value"].to_i : 0,
          threads_created: stats["Threads_created"] || 0,
          threads_cached: stats["Threads_cached"] || 0
        }
      end
    end

    def health_metrics
      with_connection do |client|
        status = {}
        client.query("SHOW GLOBAL STATUS").each do |row|
          status[row["Variable_name"]] = row["Value"]
        end

        variables = {}
        client.query("SHOW GLOBAL VARIABLES WHERE Variable_name IN ('max_connections', 'innodb_buffer_pool_size', 'uptime')").each do |row|
          variables[row["Variable_name"]] = row["Value"]
        end

        # InnoDB buffer pool hit ratio
        pool_reads = status["Innodb_buffer_pool_reads"].to_i
        pool_requests = status["Innodb_buffer_pool_read_requests"].to_i
        buffer_hit_ratio = if pool_requests > 0
          ((1.0 - (pool_reads.to_f / pool_requests)) * 100).round(2)
        else
          100.0
        end

        {
          buffer_hit_ratio: buffer_hit_ratio,
          uptime: status["Uptime"].to_i,
          slow_queries: status["Slow_queries"].to_i,
          questions: status["Questions"].to_i,
          commits: status["Com_commit"].to_i,
          rollbacks: status["Com_rollback"].to_i,
          threads_connected: status["Threads_connected"].to_i,
          threads_running: status["Threads_running"].to_i,
          open_tables: status["Open_tables"].to_i,
          aborted_connections: status["Aborted_connects"].to_i
        }
      end
    end

    # =========================================================================
    # MAINTENANCE OPERATIONS
    # =========================================================================

    def optimize_tables
      with_connection do |client|
        tables = client.query("SHOW TABLES").map { |row| row.values.first }
        return { success: true, message: "No tables to optimize" } if tables.empty?

        results = []
        tables.each do |table|
          result = client.query("OPTIMIZE TABLE `#{client.escape(table)}`")
          results << { table: table, status: result.first&.dig("Msg_text") || "OK" }
        end

        { success: true, tables_optimized: results.size, details: results }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def terminate_connections(database_name = nil)
      db_name = database_name || config.database_name
      with_connection do |client|
        result = client.query(<<~SQL)
          SELECT id FROM information_schema.processlist
          WHERE db = '#{client.escape(db_name)}'
            AND id <> CONNECTION_ID()
        SQL

        count = 0
        result.each do |row|
          client.query("KILL #{row['id'].to_i}")
          count += 1
        rescue Mysql2::Error
          # Process may have already exited
        end

        { success: true, terminated_count: count }
      end
    rescue Mysql2::Error => e
      { success: false, error: e.message, terminated_count: 0 }
    end

    # =========================================================================
    # UTILITY METHODS
    # =========================================================================

    def supported_features
      [:optimize, :analyze]
    end

    protected

    def connection_string
      "mysql://#{config.username}:***@#{config.host}:#{config.port}/#{config.database_name}"
    end

    private

    def mysql_client_params
      {
        host: config.host,
        port: config.port.to_i,
        database: config.database_name,
        username: config.username,
        password: config.password,
        connect_timeout: 10,
        read_timeout: 30,
        encoding: "utf8mb4"
      }.tap do |params|
        if config.respond_to?(:ssl_mode) && config.ssl_mode.present? && config.ssl_mode != "disable"
          params[:ssl_mode] = :required
        end
      end
    end

    def mysql_client
      Mysql2::Client.new(mysql_client_params)
    end

    def with_connection
      client = mysql_client
      yield client
    rescue Mysql2::Error => e
      { error: e.message }
    ensure
      client&.close
    end

    def build_mysql_env
      { "MYSQL_PWD" => config.password }
    end

    # =========================================================================
    # BACKUP HELPERS
    # =========================================================================

    def validate_mysqldump!
      unless system("which mysqldump > /dev/null 2>&1")
        raise "mysqldump not found in PATH. Install MySQL client tools."
      end
    end

    def validate_mysql_client!
      unless system("which mysql > /dev/null 2>&1")
        raise "mysql client not found in PATH. Install MySQL client tools."
      end
    end

    def validate_backup_file!(path)
      raise "Backup file not found: #{path}" unless File.exist?(path)
    end

    def build_mysqldump_command(output_path, options)
      cmd = ["mysqldump"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--user=#{config.username}"
      cmd << "--single-transaction"
      cmd << "--routines"
      cmd << "--triggers"
      cmd << "--no-tablespaces"
      cmd << "--set-gtid-purged=OFF" if options[:skip_gtid]
      cmd << "--verbose" if options[:verbose]

      # Table filtering
      Array(options[:tables]).each { |t| cmd << "--tables" << t }
      Array(options[:exclude_tables]).each { |t| cmd << "--ignore-table=#{config.database_name}.#{t}" }

      cmd << "--result-file=#{output_path}"
      cmd << config.database_name
      cmd.join(" ")
    end

    def build_mysql_restore_command(backup_path, options)
      cmd = ["mysql"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--user=#{config.username}"
      cmd << config.database_name
      cmd << "< #{backup_path}"
      cmd.join(" ")
    end
  end
end

# Register MySQL adapter with the factory
DatabaseAdapterFactory.register(:mysql, DatabaseAdapters::Mysql)
