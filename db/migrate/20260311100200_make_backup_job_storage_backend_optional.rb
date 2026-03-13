# frozen_string_literal: true

class MakeBackupJobStorageBackendOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :backup_jobs, :storage_backend_id, true
  end
end
