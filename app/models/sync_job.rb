# frozen_string_literal: true

class SyncJob < ApplicationRecord
  belongs_to :user
  belongs_to :source_database_config, class_name: "DatabaseConfig"
  has_many :sync_job_targets, dependent: :destroy
  has_many :target_database_configs, through: :sync_job_targets, source: :database_config
  has_many :sync_executions, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :interval_minutes, numericality: { only_integer: true, greater_than: 0 }
  validate :targets_must_differ_from_source
  validate :targets_same_engine_as_source
  validate :interval_within_plan_limit

  STATUSES = %w[idle running failed].freeze

  scope :enabled, -> { where(enabled: true) }
  scope :due, -> { enabled.where("next_run_at <= ?", Time.current) }

  before_create :set_next_run_at
  after_save :recalculate_next_run, if: -> { saved_change_to_enabled? || saved_change_to_interval_minutes? }

  def run_now!
    return false if running?

    SyncExecutionJob.perform_later(id)
    true
  end

  def pause!
    update!(enabled: false)
  end

  def resume!
    update!(enabled: true, next_run_at: Time.current + interval_minutes.minutes)
  end

  def running?
    status == "running"
  end

  def idle?
    status == "idle"
  end

  def failed?
    status == "failed"
  end

  def due?
    enabled? && next_run_at.present? && next_run_at <= Time.current
  end

  def success_rate
    total = sync_executions.count
    return 0.0 if total.zero?

    completed = sync_executions.where(status: "completed").count
    (completed.to_f / total * 100).round(2)
  end

  def last_successful_execution
    sync_executions.where(status: "completed").order(completed_at: :desc).first
  end

  def interval_label
    if interval_minutes < 60
      "Every #{interval_minutes} min"
    elsif interval_minutes == 60
      "Every hour"
    elsif interval_minutes < 1440
      hours = interval_minutes / 60
      "Every #{hours} hour#{hours == 1 ? '' : 's'}"
    else
      days = interval_minutes / 1440
      "Every #{days} day#{days == 1 ? '' : 's'}"
    end
  end

  private

  def set_next_run_at
    self.next_run_at = Time.current + interval_minutes.minutes if enabled?
  end

  def recalculate_next_run
    return unless enabled?

    update_column(:next_run_at, Time.current + interval_minutes.minutes)
  end

  def targets_must_differ_from_source
    return unless source_database_config_id.present?

    if sync_job_targets.any? { |t| t.database_config_id == source_database_config_id }
      errors.add(:base, "Target databases cannot include the source database")
    end
  end

  def interval_within_plan_limit
    return unless user
    min = user.plan_limits[:min_sync_interval_minutes]
    return unless min
    if interval_minutes < min
      errors.add(:interval_minutes, "must be at least #{min} minutes on your current plan")
    end
  end

  def targets_same_engine_as_source
    return unless source_database_config.present?

    source_type = source_database_config.database_type
    incompatible = sync_job_targets.select do |t|
      t.database_config&.database_type != source_type
    end

    if incompatible.any?
      errors.add(:base, "All target databases must be the same engine as the source (#{source_database_config.display_engine_name})")
    end
  end
end
