# frozen_string_literal: true

module DatabaseAdapters
  # Abstract base class for database adapters.
  # All database-specific adapters (PostgreSQL, MySQL, etc.) must inherit from this class
  # and implement all abstract methods.
  #
  # Usage:
  #   adapter = DatabaseAdapterFactory.for(database_config)
  #   adapter.test_connection
  #   adapter.backup(output_path: "/tmp/backup.dump", format: :custom)
  #
  class Base
    attr_reader :config

    # @param config [DatabaseConfig] The database configuration record
    def initialize(config)
      @config = config
    end

    # Connection parameters hash for this database
    # @return [Hash] Connection parameters (host, port, database, username, password)
    def connection_params
      {
        host: config.host,
        port: config.port,
        database: config.database_name,
        username: config.username,
        password: config.password
      }
    end

    # =========================================================================
    # CONNECTION & HEALTH
    # =========================================================================

    # Test the database connection
    # @return [Hash] { success: Boolean, message: String, error: String (if failed) }
    def test_connection
      raise NotImplementedError, "#{self.class} must implement #test_connection"
    end

    # Get the database server version
    # @return [String] Version string (e.g., "16.1")
    def server_version
      raise NotImplementedError, "#{self.class} must implement #server_version"
    end

    # =========================================================================
    # BACKUP & RESTORE
    # =========================================================================

    # Create a backup of the database
    # @param output_path [String] Path to write the backup file
    # @param format [Symbol] Backup format (:custom, :plain, :directory, :tar)
    # @param options [Hash] Additional options (compression, tables, exclude_tables, etc.)
    # @return [Hash] { success: Boolean, file_path: String, file_size: Integer, error: String }
    def backup(output_path:, format: :custom, options: {})
      raise NotImplementedError, "#{self.class} must implement #backup"
    end

    # Restore a database from backup
    # @param backup_path [String] Path to the backup file
    # @param options [Hash] Additional options (clean, create, single_transaction, etc.)
    # @return [Hash] { success: Boolean, message: String, error: String }
    def restore(backup_path:, options: {})
      raise NotImplementedError, "#{self.class} must implement #restore"
    end

    # Get supported backup formats for this database type
    # @return [Array<Symbol>] List of supported formats
    def supported_backup_formats
      raise NotImplementedError, "#{self.class} must implement #supported_backup_formats"
    end

    # =========================================================================
    # DATABASE INFORMATION
    # =========================================================================

    # Get the size of the database
    # @return [Integer] Size in bytes
    def database_size
      raise NotImplementedError, "#{self.class} must implement #database_size"
    end

    # List all databases on the server
    # @return [Array<String>] Database names
    def list_databases
      raise NotImplementedError, "#{self.class} must implement #list_databases"
    end

    # List all tables in the database
    # @return [Array<Hash>] Table info with name, row_count, size
    def list_tables
      raise NotImplementedError, "#{self.class} must implement #list_tables"
    end

    # =========================================================================
    # STATISTICS & MONITORING
    # =========================================================================

    # Get table statistics
    # @return [Array<Hash>] Stats for each table
    def table_statistics
      raise NotImplementedError, "#{self.class} must implement #table_statistics"
    end

    # Get connection/session statistics
    # @return [Hash] Connection stats (active, idle, max, etc.)
    def connection_statistics
      raise NotImplementedError, "#{self.class} must implement #connection_statistics"
    end

    # Get overall database health metrics
    # @return [Hash] Health metrics specific to database type
    def health_metrics
      raise NotImplementedError, "#{self.class} must implement #health_metrics"
    end

    # =========================================================================
    # MAINTENANCE OPERATIONS
    # =========================================================================

    # Terminate active connections to the database
    # @param database_name [String] Name of database (defaults to configured database)
    # @return [Hash] { success: Boolean, terminated_count: Integer }
    def terminate_connections(database_name = nil)
      raise NotImplementedError, "#{self.class} must implement #terminate_connections"
    end

    # =========================================================================
    # UTILITY METHODS
    # =========================================================================

    # Human-readable name for this database type
    # @return [String]
    def database_type_name
      self.class.name.demodulize
    end

    # Check if this adapter supports a specific feature
    # @param feature [Symbol] Feature name (:vacuum, :analyze, :replication, etc.)
    # @return [Boolean]
    def supports?(feature)
      supported_features.include?(feature)
    end

    # List of features supported by this adapter
    # @return [Array<Symbol>]
    def supported_features
      []
    end

    protected

    # Execute a command with environment variables
    # @param command [String] Command to execute
    # @param env [Hash] Environment variables
    # @param timeout [Integer] Timeout in seconds
    # @return [Hash] { success: Boolean, stdout: String, stderr: String, exit_code: Integer }
    def execute_command(command, env: {}, timeout: 3600)
      stdout, stderr, status = nil

      Timeout.timeout(timeout) do
        stdout, stderr, status = Open3.capture3(env, command)
      end

      {
        success: status.success?,
        stdout: stdout,
        stderr: stderr,
        exit_code: status.exitstatus
      }
    rescue Timeout::Error
      {
        success: false,
        stdout: "",
        stderr: "Command timed out after #{timeout} seconds",
        exit_code: -1
      }
    end

    # Build a connection string for command-line tools
    # @return [String]
    def connection_string
      raise NotImplementedError, "#{self.class} must implement #connection_string"
    end
  end
end
