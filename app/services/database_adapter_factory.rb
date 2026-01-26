# frozen_string_literal: true

# Factory for creating database adapters based on database type.
#
# Usage:
#   adapter = DatabaseAdapterFactory.for(database_config)
#   adapter.test_connection
#
# Registering new adapters:
#   DatabaseAdapterFactory.register(:mysql, DatabaseAdapters::Mysql)
#
class DatabaseAdapterFactory
  # Error raised when an unsupported database type is requested
  class UnsupportedDatabaseError < StandardError
    def initialize(database_type)
      super("Unsupported database type: #{database_type}. Supported types: #{DatabaseAdapterFactory.supported_types.join(', ')}")
    end
  end

  # Registry of database type to adapter class mappings
  @adapters = {}

  class << self
    # Register an adapter class for a database type
    # @param type [Symbol, String] Database type (e.g., :postgresql, :mysql)
    # @param adapter_class [Class] Adapter class that inherits from DatabaseAdapters::Base
    def register(type, adapter_class)
      @adapters[type.to_sym] = adapter_class
    end

    # Get an adapter instance for a database configuration
    # @param database_config [DatabaseConfig] The database configuration record
    # @return [DatabaseAdapters::Base] An adapter instance
    # @raise [UnsupportedDatabaseError] If the database type is not supported
    def for(database_config)
      type = database_config.database_type&.to_sym || :postgresql
      adapter_class = @adapters[type]

      raise UnsupportedDatabaseError, type unless adapter_class

      adapter_class.new(database_config)
    end

    # Alias for #for method
    alias_method :build, :for
    alias_method :create, :for

    # List all supported database types
    # @return [Array<Symbol>]
    def supported_types
      @adapters.keys
    end

    # Check if a database type is supported
    # @param type [Symbol, String] Database type
    # @return [Boolean]
    def supports?(type)
      @adapters.key?(type.to_sym)
    end

    # Get the adapter class for a database type (without instantiating)
    # @param type [Symbol, String] Database type
    # @return [Class, nil]
    def adapter_class_for(type)
      @adapters[type.to_sym]
    end

    # Clear all registered adapters (mainly for testing)
    def reset!
      @adapters = {}
    end

    # Get all registered adapters
    # @return [Hash<Symbol, Class>]
    def registered_adapters
      @adapters.dup
    end
  end
end

# Register built-in adapters
# PostgreSQL adapter is registered after it's defined (see postgresql.rb)
