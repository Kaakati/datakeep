# frozen_string_literal: true

class AddEncryptionKeyToBackupJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :backup_jobs, :encryption_key, :text
  end
end
