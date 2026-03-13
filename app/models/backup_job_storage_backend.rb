# frozen_string_literal: true

class BackupJobStorageBackend < ApplicationRecord
  belongs_to :backup_job
  belongs_to :storage_backend

  validates :backup_job_id, uniqueness: { scope: :storage_backend_id }
end
