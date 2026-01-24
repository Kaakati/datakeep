# frozen_string_literal: true

class NotificationChannel < ApplicationRecord
  belongs_to :user
  has_many :backup_job_notification_channels, dependent: :destroy
  has_many :backup_jobs, through: :backup_job_notification_channels

  encrypts :encrypted_config

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :type, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }

  def config
    return {} if encrypted_config.blank?
    JSON.parse(encrypted_config, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  def config=(value)
    self.encrypted_config = value.is_a?(String) ? value : value.to_json
  end

  def send_notification(event, backup = nil)
    raise NotImplementedError, "Subclasses must implement #send_notification"
  end

  def test_notification
    raise NotImplementedError, "Subclasses must implement #test_notification"
  end

  def channel_type
    self.class.name.demodulize.underscore.gsub("_channel", "")
  end

  protected

  def build_message(event, backup)
    case event.to_s
    when "success"
      success_message(backup)
    when "failure"
      failure_message(backup)
    when "test"
      test_message
    else
      "Database-Ops notification: #{event}"
    end
  end

  def success_message(backup)
    return "Backup completed successfully" unless backup

    "Backup completed successfully!\n" \
    "Database: #{backup.database_name}\n" \
    "Size: #{backup.formatted_file_size}\n" \
    "Duration: #{backup.formatted_duration}"
  end

  def failure_message(backup)
    return "Backup failed" unless backup

    "Backup failed!\n" \
    "Database: #{backup.database_name}\n" \
    "Error: #{backup.error_message}"
  end

  def test_message
    "This is a test notification from Database-Ops"
  end
end
