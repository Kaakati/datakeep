# frozen_string_literal: true

class BackfillBackupJobStorageBackends < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO backup_job_storage_backends (backup_job_id, storage_backend_id, created_at, updated_at)
      SELECT id, storage_backend_id, NOW(), NOW()
      FROM backup_jobs
      WHERE storage_backend_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    execute "DELETE FROM backup_job_storage_backends"
  end
end
