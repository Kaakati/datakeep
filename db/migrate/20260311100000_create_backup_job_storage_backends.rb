# frozen_string_literal: true

class CreateBackupJobStorageBackends < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_job_storage_backends do |t|
      t.references :backup_job, null: false, foreign_key: true
      t.references :storage_backend, null: false, foreign_key: true
      t.timestamps
    end

    add_index :backup_job_storage_backends, [ :backup_job_id, :storage_backend_id ],
              unique: true, name: "idx_backup_job_storage_backend_unique"
  end
end
