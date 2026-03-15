# frozen_string_literal: true

class RenamePgVersionToEngineVersion < ActiveRecord::Migration[8.1]
  def change
    rename_column :database_configs, :pg_version, :engine_version
    rename_column :backups, :pg_version, :engine_version
  end
end
