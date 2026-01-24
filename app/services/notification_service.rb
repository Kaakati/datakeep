# frozen_string_literal: true

class NotificationService
  attr_reader :notification_channel, :event, :backup

  def initialize(notification_channel:, event:, backup: nil)
    @notification_channel = notification_channel
    @event = event.to_sym
    @backup = backup
  end

  def deliver
    return { success: false, error: "Channel is disabled" } unless notification_channel.enabled?

    # Check if we should send based on event type
    case event
    when :success
      return { success: false, skipped: true } unless notification_channel.notify_on_success?
    when :failure
      return { success: false, skipped: true } unless notification_channel.notify_on_failure?
    end

    notification_channel.send_notification(event, backup)
  rescue StandardError => e
    Rails.logger.error "[NotificationService] Failed to send notification: #{e.message}"
    { success: false, error: e.message }
  end

  class << self
    def notify_backup_success(backup)
      notify_for_backup(backup, :success)
    end

    def notify_backup_failure(backup)
      notify_for_backup(backup, :failure)
    end

    def notify_for_backup(backup, event)
      backup.backup_job.notification_channels.enabled.find_each do |channel|
        NotificationJob.perform_later(channel.id, event.to_s, backup.id)
      end
    end

    def test_channel(notification_channel)
      new(
        notification_channel: notification_channel,
        event: :test
      ).deliver
    end
  end
end
