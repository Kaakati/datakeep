# frozen_string_literal: true

# Register all database adapters on application boot
# This ensures adapters are available regardless of eager loading settings

Rails.application.config.after_initialize do
  # Explicitly load and register the PostgreSQL adapter
  require_dependency "database_adapters/postgresql"
end
