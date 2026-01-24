class Restore < ApplicationRecord
  belongs_to :user
  belongs_to :database_config
  belongs_to :backup, optional: true

  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, default: :pending

  validates :database_config_id, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def formatted_duration
    return "-" unless duration
    if duration < 60
      "#{duration.round}s"
    elsif duration < 3600
      "#{(duration / 60).round}m"
    else
      "#{(duration / 3600).round}h #{((duration % 3600) / 60).round}m"
    end
  end
end
