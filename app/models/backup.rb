# frozen_string_literal: true

class Backup < ApplicationRecord
  belongs_to :backup_job
  belongs_to :storage_backend

  validates :file_name, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

  STATUSES = %w[pending running completed failed].freeze

  scope :pending, -> { where(status: "pending") }
  scope :running, -> { where(status: "running") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { order(created_at: :desc) }
  scope :expired, ->(retention_days) { where("created_at < ?", retention_days.days.ago) }

  delegate :user, to: :backup_job

  def pending?
    status == "pending"
  end

  def running?
    status == "running"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def formatted_duration
    return "N/A" unless duration

    if duration < 60
      "#{duration.round(1)}s"
    elsif duration < 3600
      "#{(duration / 60).round(1)}m"
    else
      "#{(duration / 3600).round(1)}h"
    end
  end

  def formatted_file_size
    return "N/A" unless file_size

    if file_size < 1024
      "#{file_size} B"
    elsif file_size < 1024 * 1024
      "#{(file_size / 1024.0).round(2)} KB"
    elsif file_size < 1024 * 1024 * 1024
      "#{(file_size / (1024.0 * 1024)).round(2)} MB"
    else
      "#{(file_size / (1024.0 * 1024 * 1024)).round(2)} GB"
    end
  end

  def start!
    update!(
      status: "running",
      started_at: Time.current
    )
  end

  def complete!(file_path:, file_size:, checksum:)
    update!(
      status: "completed",
      file_path: file_path,
      file_size: file_size,
      checksum: checksum,
      completed_at: Time.current
    )
  end

  def fail!(error_message)
    update!(
      status: "failed",
      error_message: error_message,
      completed_at: Time.current
    )
  end

  def restorable?
    completed? && storage_backend.exists?(file_path)
  end

  def download_url
    return nil unless completed?
    # This would be implemented based on storage type
    # For local storage, we'd serve from disk
    # For S3, we'd generate a presigned URL
    nil
  end

  def display_name
    "#{backup_job.name} - #{created_at.strftime('%b %d, %Y %H:%M')} (#{formatted_file_size})"
  end

  # Alias for view consistency
  alias_method :formatted_size, :formatted_file_size

  def encrypted?
    backup_job&.encryption?
  end

  def compressed?
    backup_job&.compression?
  end
end
