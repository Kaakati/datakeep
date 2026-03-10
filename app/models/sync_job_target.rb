# frozen_string_literal: true

class SyncJobTarget < ApplicationRecord
  belongs_to :sync_job
  belongs_to :database_config

  validate :target_must_differ_from_source

  private

  def target_must_differ_from_source
    return unless sync_job&.source_database_config_id.present?

    if database_config_id == sync_job.source_database_config_id
      errors.add(:database_config, "cannot be the same as the source database")
    end
  end
end
