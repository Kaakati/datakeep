# frozen_string_literal: true

class SyncExecution < ApplicationRecord
  belongs_to :sync_job

  STATUSES = %w[pending running completed failed].freeze

  scope :recent, -> { order(created_at: :desc) }

  def duration
    return nil unless started_at && completed_at

    completed_at - started_at
  end

  def partially_failed?
    status == "completed" && targets_succeeded < targets_count
  end
end
