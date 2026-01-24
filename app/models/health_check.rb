# frozen_string_literal: true

class HealthCheck < ApplicationRecord
  belongs_to :database_config

  STATUSES = %w[healthy unhealthy].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :checked_at, presence: true

  scope :recent, -> { order(checked_at: :desc) }
  scope :healthy, -> { where(status: "healthy") }
  scope :unhealthy, -> { where(status: "unhealthy") }
  scope :within_period, ->(days) { where("checked_at >= ?", days.days.ago) }
  scope :today, -> { where("checked_at >= ?", Time.current.beginning_of_day) }

  def self.cleanup_old_records!(retention_days: 30)
    where("checked_at < ?", retention_days.days.ago).delete_all
  end

  def healthy?
    status == "healthy"
  end

  def unhealthy?
    status == "unhealthy"
  end
end
