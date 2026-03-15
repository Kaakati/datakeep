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

  SUPPORTED_DATABASE_TYPES = %w[postgresql mysql mongodb].freeze

  # Built-in adapters — always available regardless of load order
  BUILT_IN_ADAPTERS = {
    postgresql: "DatabaseAdapters::Postgresql",
    postgres: "DatabaseAdapters::Postgresql",
    mysql: "DatabaseAdapters::Mysql",
    mongodb: "DatabaseAdapters::Mongodb"
  }.freeze

  class << self
    # Register an adapter class for a database type
    def register(type, adapter_class)
      extra_adapters[type.to_sym] = adapter_class
    end

    # Get an adapter instance for a database configuration
    def for(database_config)
      type = database_config.database_type&.to_sym || :postgresql
      adapter_class = extra_adapters[type] || resolve_built_in(type)

      raise UnsupportedDatabaseError, type unless adapter_class

      adapter_class.new(database_config)
    end

    alias_method :build, :for
    alias_method :create, :for

    def supported_types
      (BUILT_IN_ADAPTERS.keys + extra_adapters.keys).uniq
    end

    def supports?(type)
      BUILT_IN_ADAPTERS.key?(type.to_sym) || extra_adapters.key?(type.to_sym)
    end

    def adapter_class_for(type)
      extra_adapters[type.to_sym] || resolve_built_in(type)
    end

    def reset!
      @extra_adapters = {}
    end

    def registered_adapters
      built = BUILT_IN_ADAPTERS.transform_values { |name| name.constantize rescue nil }.compact
      built.merge(extra_adapters)
    end

    private

    def extra_adapters
      @extra_adapters ||= {}
    end

    def resolve_built_in(type)
      class_name = BUILT_IN_ADAPTERS[type.to_sym]
      return nil unless class_name

      class_name.constantize
    rescue NameError
      nil
    end
  end
end
