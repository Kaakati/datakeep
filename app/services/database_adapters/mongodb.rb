# frozen_string_literal: true

require "open3"

module DatabaseAdapters
  # MongoDB database adapter implementing all database operations
  # for MongoDB databases using the mongo gem and command-line tools (mongodump, mongorestore).
  #
  # Usage:
  #   adapter = DatabaseAdapterFactory.for(database_config)
  #   adapter.test_connection
  #   adapter.backup(output_path: "/tmp/backup.archive", format: :archive)
  #
  class Mongodb < Base
    # =========================================================================
    # CONNECTION & HEALTH
    # =========================================================================

    def test_connection
      client = mongo_client
      result = client.database.command(ping: 1)

      build_info = client.database.command(buildInfo: 1).first
      version = build_info["version"]

      {
        success: true,
        message: "Connected successfully",
        version: "MongoDB #{version}",
        server_version: version
      }
    rescue StandardError => e
      { success: false, error: e.message }
    ensure
      client&.close
    end

    def server_version
      client = mongo_client
      result = client.database.command(buildInfo: 1).first
      result["version"]
    rescue StandardError
      nil
    ensure
      client&.close
    end

    # =========================================================================
    # BACKUP & RESTORE
    # =========================================================================

    def backup(output_path:, format: :archive, options: {})
      validate_mongodump!

      cmd = build_mongodump_command(output_path, options)
      result = execute_command(cmd, timeout: options[:timeout] || 3600)

      if result[:success]
        {
          success: true,
          file_path: output_path,
          file_size: File.size(output_path),
          format: :archive
        }
      else
        { success: false, error: result[:stderr] }
      end
    end

    def restore(backup_path:, options: {})
      validate_mongorestore!
      validate_backup_file!(backup_path)

      cmd = build_mongorestore_command(backup_path, options)
      result = execute_command(cmd, timeout: options[:timeout] || 3600)

      if result[:success]
        { success: true, message: "Restore completed", warnings: result[:stderr] }
      else
        { success: false, error: result[:stderr] }
      end
    end

    def supported_backup_formats
      [:archive, :directory]
    end

    # =========================================================================
    # DATABASE INFORMATION
    # =========================================================================

    def database_size
      with_connection do |client|
        stats = client.database.command(dbStats: 1).first
        stats["dataSize"].to_i
      end
    end

    def list_databases
      with_connection do |client|
        result = client.use("admin").database.command(listDatabases: 1).first
        result["databases"].map do |db|
          {
            name: db["name"],
            size: db["sizeOnDisk"].to_i,
            owner: nil,
            encoding: nil
          }
        end
      end
    end

    def list_tables
      with_connection do |client|
        collections = client.database.list_collections
        collections.map do |col|
          stats = begin
            client.database.command(collStats: col["name"]).first
          rescue StandardError
            {}
          end

          {
            schema: nil,
            name: col["name"],
            row_count: stats["count"].to_i,
            total_size: stats["storageSize"].to_i + (stats["totalIndexSize"] || 0).to_i,
            table_size: stats["storageSize"].to_i
          }
        end
      end
    end

    # =========================================================================
    # STATISTICS & MONITORING
    # =========================================================================

    def table_statistics
      with_connection do |client|
        collections = client.database.list_collections
        collections.map do |col|
          stats = begin
            client.database.command(collStats: col["name"]).first
          rescue StandardError
            {}
          end

          {
            name: col["name"],
            row_count: stats["count"].to_i,
            storage_size: stats["storageSize"].to_i,
            index_count: stats["nindexes"].to_i,
            total_index_size: stats["totalIndexSize"].to_i,
            avg_obj_size: stats["avgObjSize"].to_i
          }
        end
      end
    end

    def connection_statistics
      with_connection do |client|
        status = client.database.command(serverStatus: 1).first
        connections = status["connections"] || {}

        {
          active: connections["active"].to_i,
          idle: connections["available"].to_i,
          total: connections["current"].to_i,
          max_connections: connections["totalCreated"].to_i
        }
      end
    end

    def health_metrics
      with_connection do |client|
        status = client.database.command(serverStatus: 1).first

        opcounters = status["opcounters"] || {}
        mem = status["mem"] || {}
        connections = status["connections"] || {}

        repl_status = begin
          client.database.command(replSetGetStatus: 1).first
        rescue StandardError
          nil
        end

        metrics = {
          uptime: status["uptime"].to_i,
          inserts: opcounters["insert"].to_i,
          queries: opcounters["query"].to_i,
          updates: opcounters["update"].to_i,
          deletes: opcounters["delete"].to_i,
          resident_memory_mb: mem["resident"].to_i,
          virtual_memory_mb: mem["virtual"].to_i,
          current_connections: connections["current"].to_i,
          available_connections: connections["available"].to_i
        }

        if repl_status
          metrics[:replication] = {
            set_name: repl_status["set"],
            my_state: repl_status["myState"],
            members: repl_status["members"]&.size || 0
          }
        end

        metrics
      end
    end

    # =========================================================================
    # MAINTENANCE OPERATIONS
    # =========================================================================

    def compact_database
      with_connection do |client|
        collections = client.database.list_collections.map { |c| c["name"] }
        return { success: true, message: "No collections to compact" } if collections.empty?

        results = []
        collections.each do |col|
          begin
            client.database.command(compact: col)
            results << { collection: col, status: "OK" }
          rescue StandardError => e
            results << { collection: col, status: "Error: #{e.message}" }
          end
        end

        { success: true, collections_compacted: results.size, details: results }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def terminate_connections(database_name = nil)
      with_connection do |client|
        # MongoDB doesn't have a direct way to kill all connections to a DB.
        # We can kill operations instead.
        ops = client.database.command(currentOp: 1, "$all" => true).first
        inprog = ops["inprog"] || []

        db_name = database_name || config.database_name
        count = 0

        inprog.each do |op|
          next unless op["ns"]&.start_with?("#{db_name}.")
          next if op["opid"].nil?

          begin
            client.database.command(killOp: 1, op: op["opid"])
            count += 1
          rescue StandardError
            # Op may have completed
          end
        end

        { success: true, terminated_count: count }
      end
    rescue StandardError => e
      { success: false, error: e.message, terminated_count: 0 }
    end

    # =========================================================================
    # UTILITY METHODS
    # =========================================================================

    def supported_features
      [:compact, :replication]
    end

    protected

    def connection_string
      "mongodb://#{config.username}:***@#{config.host}:#{config.port}/#{config.database_name}"
    end

    private

    def mongo_uri
      auth = if config.username.present?
        "#{URI.encode_www_form_component(config.username)}:#{URI.encode_www_form_component(config.password)}@"
      else
        ""
      end

      params = []
      params << "authSource=admin" if config.username.present?
      if config.respond_to?(:ssl_mode) && config.ssl_mode.present? && config.ssl_mode != "disable"
        params << "tls=true"
      end

      query = params.any? ? "?#{params.join('&')}" : ""
      "mongodb://#{auth}#{config.host}:#{config.port}/#{config.database_name}#{query}"
    end

    def mongo_client
      require "mongo"
      Mongo::Client.new(
        mongo_uri,
        server_selection_timeout: 10,
        connect_timeout: 10,
        socket_timeout: 30
      )
    end

    def with_connection
      client = mongo_client
      yield client
    rescue StandardError => e
      { error: e.message }
    ensure
      client&.close
    end

    # =========================================================================
    # BACKUP HELPERS
    # =========================================================================

    def validate_mongodump!
      unless system("which mongodump > /dev/null 2>&1")
        raise "mongodump not found in PATH. Install MongoDB Database Tools."
      end
    end

    def validate_mongorestore!
      unless system("which mongorestore > /dev/null 2>&1")
        raise "mongorestore not found in PATH. Install MongoDB Database Tools."
      end
    end

    def validate_backup_file!(path)
      raise "Backup file not found: #{path}" unless File.exist?(path)
    end

    def build_mongodump_command(output_path, options)
      cmd = ["mongodump"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--db=#{config.database_name}"

      if config.username.present?
        cmd << "--username=#{config.username}"
        cmd << "--password=#{config.password}"
        cmd << "--authenticationDatabase=#{options[:auth_db] || 'admin'}"
      end

      cmd << "--archive=#{output_path}"
      cmd << "--gzip" if options.fetch(:gzip, true)

      # Collection filtering
      Array(options[:tables]).each { |c| cmd << "--collection=#{c}" }
      Array(options[:exclude_tables]).each { |c| cmd << "--excludeCollection=#{c}" }

      cmd << "--ssl" if config.respond_to?(:ssl_mode) && config.ssl_mode.present? && config.ssl_mode != "disable"
      cmd << "--verbose" if options[:verbose]

      cmd.join(" ")
    end

    def build_mongorestore_command(backup_path, options)
      cmd = ["mongorestore"]
      cmd << "--host=#{config.host}"
      cmd << "--port=#{config.port}"
      cmd << "--db=#{config.database_name}"

      if config.username.present?
        cmd << "--username=#{config.username}"
        cmd << "--password=#{config.password}"
        cmd << "--authenticationDatabase=#{options[:auth_db] || 'admin'}"
      end

      cmd << "--archive=#{backup_path}"
      cmd << "--gzip" if options.fetch(:gzip, true)
      cmd << "--drop" if options.fetch(:clean, true)

      cmd << "--ssl" if config.respond_to?(:ssl_mode) && config.ssl_mode.present? && config.ssl_mode != "disable"
      cmd << "--verbose" if options[:verbose]

      cmd.join(" ")
    end
  end
end

# Register MongoDB adapter with the factory
DatabaseAdapterFactory.register(:mongodb, DatabaseAdapters::Mongodb)
