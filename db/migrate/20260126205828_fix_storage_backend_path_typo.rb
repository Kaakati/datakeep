# frozen_string_literal: true

# This migration fixes a typo in storage backend configurations where
# "/var/backup" (singular) was used instead of "/var/backups" (plural).
# The Docker volume mounts at /var/backups, so backups written to /var/backup
# would be lost on container restart.
#
# Additionally, it updates existing backup file_path records to use the
# correct path so older backups that still exist can be downloaded.
class FixStorageBackendPathTypo < ActiveRecord::Migration[8.1]
  def up
    # Fix storage backend configurations
    # Note: encrypted_config is an encrypted column, so we use the model
    StorageBackends::LocalStorage.find_each do |storage|
      config = storage.config
      if config[:path]&.include?("/var/backup/")
        corrected_path = config[:path].gsub("/var/backup/", "/var/backups/")
        storage.update!(config: config.merge(path: corrected_path))
        Rails.logger.info "[Migration] Updated storage backend #{storage.id}: #{config[:path]} -> #{corrected_path}"
      end
    end

    # Fix existing backup file paths
    Backup.where("file_path LIKE ?", "%/var/backup/%").find_each do |backup|
      corrected_path = backup.file_path.gsub("/var/backup/", "/var/backups/")
      backup.update_column(:file_path, corrected_path)
      Rails.logger.info "[Migration] Updated backup #{backup.id} file_path: #{backup.file_path_was} -> #{corrected_path}"
    end
  end

  def down
    # This migration fixes a typo, so reversing it would reintroduce the bug.
    # However, for completeness, we provide a reversal path.
    StorageBackends::LocalStorage.find_each do |storage|
      config = storage.config
      if config[:path]&.include?("/var/backups/")
        reverted_path = config[:path].gsub("/var/backups/", "/var/backup/")
        storage.update!(config: config.merge(path: reverted_path))
      end
    end

    Backup.where("file_path LIKE ?", "%/var/backups/%").find_each do |backup|
      reverted_path = backup.file_path.gsub("/var/backups/", "/var/backup/")
      backup.update_column(:file_path, reverted_path)
    end
  end
end
