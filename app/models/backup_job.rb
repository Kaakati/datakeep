# frozen_string_literal: true

class BackupJob < ApplicationRecord
  encrypts :encryption_key

  belongs_to :user
  belongs_to :database_config
  belongs_to :storage_backend, optional: true
  has_many :backups, dependent: :destroy
  has_many :backup_job_notification_channels, dependent: :destroy
  has_many :notification_channels, through: :backup_job_notification_channels
  has_many :backup_job_storage_backends, dependent: :destroy
  has_many :storage_backends, through: :backup_job_storage_backends

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validate :at_least_one_storage_backend
  validates :schedule_type, presence: true, inclusion: { in: %w[hourly daily weekly monthly custom] }
  validates :retention_days, numericality: { only_integer: true, greater_than: 0 }
  validate :retention_within_plan_limit
  validate :frequency_within_plan_limit
  validates :cron_expression, presence: true, if: -> { schedule_type == "custom" }
  validate :validate_cron_expression, if: -> { cron_expression.present? }

  SCHEDULE_TYPES = %w[hourly daily weekly monthly custom].freeze
  STATUSES = %w[idle running failed].freeze

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :due, -> { enabled.where("next_run_at <= ?", Time.current) }

  before_create :calculate_next_run
  before_save :manage_encryption_key
  after_save :reschedule_job, if: -> { saved_change_to_enabled? || saved_change_to_schedule_type? || saved_change_to_cron_expression? }

  def cron_schedule
    @cron_schedule ||= case schedule_type
    when "hourly"
      "0 * * * *"
    when "daily"
      "0 0 * * *"
    when "weekly"
      "0 0 * * 0"
    when "monthly"
      "0 0 1 * *"
    when "custom"
      cron_expression
    end
  end

  def calculate_next_run
    return unless enabled?

    parsed = Fugit.parse(cron_schedule)
    self.next_run_at = parsed&.next_time&.to_t
  end

  def run_now!
    return false if running?

    # Don't set status here - let the job handle it to avoid race condition
    BackupExecutionJob.perform_later(id)
    true
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

  # Returns the storage backends for this job.
  # Uses the join table if populated, falls back to legacy single storage_backend.
  def effective_storage_backends
    backends = storage_backends.to_a
    if backends.any?
      backends
    elsif storage_backend.present?
      [ storage_backend ]
    else
      []
    end
  end

  def pause!
    update!(enabled: false)
  end

  def resume!
    update!(enabled: true)
    calculate_next_run
    save!
  end

  def last_successful_backup
    backups.completed.order(completed_at: :desc).first
  end

  def success_rate
    total = backups.count
    return 0.0 if total.zero?

    completed = backups.completed.count
    (completed.to_f / total * 100).round(2)
  end

  def notify_channels(event, backup: nil)
    notification_channels.enabled.each do |channel|
      next if event == :success && !channel.notify_on_success?
      next if event == :failure && !channel.notify_on_failure?

      NotificationJob.perform_later(channel.id, event.to_s, backup&.id)
    end
  end

  private

  SCHEDULE_INTERVAL_MINUTES = {
    "hourly" => 60,
    "daily" => 1440,
    "weekly" => 10_080,
    "monthly" => 43_200
  }.freeze

  def frequency_within_plan_limit
    return unless user && schedule_type.present?
    min_minutes = user.plan_limits[:min_backup_interval_minutes]
    return unless min_minutes

    effective_minutes = SCHEDULE_INTERVAL_MINUTES[schedule_type]
    # For custom cron, estimate from expression
    if schedule_type == "custom" && cron_expression.present?
      effective_minutes = estimate_cron_interval_minutes
    end
    return unless effective_minutes

    if effective_minutes < min_minutes
      human = if min_minutes >= 1440
                "#{min_minutes / 1440} day(s)"
              elsif min_minutes >= 60
                "#{min_minutes / 60} hour(s)"
              else
                "#{min_minutes} minutes"
              end
      errors.add(:schedule_type, "interval is too frequent for your plan. Minimum interval is #{human}.")
    end
  end

  def estimate_cron_interval_minutes
    parsed = Fugit.parse(cron_expression)
    return nil unless parsed
    # Get next two occurrences and compute difference
    first = parsed.next_time
    second = parsed.next_time(first)
    return nil unless first && second
    ((second.to_f - first.to_f) / 60).round
  rescue
    nil
  end

  def retention_within_plan_limit
    return unless user && retention_days
    max = user.plan_limits[:max_retention_days]
    return unless max
    return if retention_days <= max

    errors.add(:retention_days, "exceeds your plan limit of #{max} days. Upgrade your plan to use longer retention periods.")
  end

  def at_least_one_storage_backend
    return if storage_backend_id.present?
    return if backup_job_storage_backends.any? { |bjsb| !bjsb.marked_for_destruction? }

    errors.add(:base, "At least one storage backend is required")
  end

  def validate_cron_expression
    Fugit.parse(cron_expression)
  rescue ArgumentError => e
    errors.add(:cron_expression, "is invalid: #{e.message}")
  end

  def manage_encryption_key
    if encryption? && encryption_key.blank?
      self.encryption_key = SecureRandom.hex(32)
    end
    # Never clear key on disable — old encrypted backups need it for restore/download
  end

  def reschedule_job
    return unless enabled?

    calculate_next_run
    save! if next_run_at_changed?
  end
end
