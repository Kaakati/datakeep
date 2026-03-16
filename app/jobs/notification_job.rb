# frozen_string_literal: true

class NotificationJob
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 3

  def perform(notification_channel_id, event, backup_id = nil)
    channel = NotificationChannel.find(notification_channel_id)
    backup = backup_id ? Backup.find_by(id: backup_id) : nil

    return unless channel.enabled?

    service = NotificationService.new(
      notification_channel: channel,
      event: event.to_sym,
      backup: backup
    )

    result = service.deliver

    if result[:skipped]
      Rails.logger.info "[NotificationJob] Notification skipped: event #{event} not enabled for channel #{channel.name}"
    elsif !result[:success]
      Rails.logger.warn "[NotificationJob] Failed to send notification: #{result[:error]}"
    end

    result
  end
end
