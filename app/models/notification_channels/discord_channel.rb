# frozen_string_literal: true

module NotificationChannels
  class DiscordChannel < NotificationChannel
    validates :encrypted_config, presence: true

    def webhook_url
      config[:webhook_url]
    end

    def send_notification(event, backup = nil)
      payload = build_discord_payload(event, backup)

      response = Faraday.post(webhook_url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = payload.to_json
      end

      if response.success? || response.status == 204
        { success: true }
      else
        { success: false, error: "Discord API returned #{response.status}" }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def test_notification
      send_notification(:test)
    end

    private

    def build_discord_payload(event, backup)
      {
        username: "Database-Ops",
        embeds: [
          {
            title: event_title(event, backup),
            description: build_message(event, backup),
            color: event_color(event),
            timestamp: Time.current.iso8601,
            footer: {
              text: "Database-Ops"
            }
          }
        ]
      }
    end

    def event_color(event)
      case event.to_s
      when "success" then 0x00FF00  # Green
      when "failure" then 0xFF0000  # Red
      else 0x0099FF  # Blue
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
