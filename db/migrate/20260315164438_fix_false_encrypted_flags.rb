# frozen_string_literal: true

class FixFalseEncryptedFlags < ActiveRecord::Migration[8.1]
  def up
    # Existing backups marked encrypted: true were never actually encrypted
    # because the encryption key was never passed through the pipeline.
    # Fix by setting encrypted: false on any backup whose file doesn't end in .enc,
    # or unconditionally since no key ever existed before this migration.
    Backup.where(encrypted: true).update_all(encrypted: false)
  end

  def down
    # Cannot reliably reverse — we don't know which were originally marked encrypted
  end
end
