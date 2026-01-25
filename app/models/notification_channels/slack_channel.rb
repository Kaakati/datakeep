# frozen_string_literal: true

module NotificationChannels
  class SlackChannel < NotificationChannel
    validates :encrypted_config, presence: true

    def webhook_url
      config[:webhook_url]
    end

    def channel
      config[:channel]
    end

    def send_notification(event, backup = nil)
      payload = build_slack_payload(event, backup)

      response = Faraday.post(webhook_url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end

      if response.success?
        { success: true }
      else
        { success: false, error: "Slack API returned #{response.status}" }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def test_notification
      send_notification(:test)
    end

    private

    def build_slack_payload(event, backup)
      {
        channel: channel,
        username: "DataKeep",
        icon_emoji: event_emoji(event),
        attachments: [
          {
            color: event_color(event),
            title: event_title(event, backup),
            text: build_message(event, backup),
            footer: "DataKeep",
            ts: Time.current.to_i
          }
        ]
      }.compact
    end

    def event_emoji(event)
      case event.to_s
      when "success" then ":white_check_mark:"
      when "failure" then ":x:"
      else ":information_source:"
      end
    end

    def event_color(event)
      case event.to_s
      when "success" then "good"
      when "failure" then "danger"
      else "#439FE0"
      end
    end

    def event_title(event, backup)
      db_name = backup&.database_name || "Database"
      case event.to_s
      when "success" then "Backup completed: #{db_name}"
      when "failure" then "Backup failed: #{db_name}"
      when "test" then "Test notification"
      else "Notification: #{event}"
      end
    end
  end
end
