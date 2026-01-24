# frozen_string_literal: true

module NotificationChannels
  class TelegramChannel < NotificationChannel
    validates :encrypted_config, presence: true

    TELEGRAM_API_URL = "https://api.telegram.org"

    def bot_token
      config[:bot_token]
    end

    def chat_id
      config[:chat_id]
    end

    def send_notification(event, backup = nil)
      message = build_telegram_message(event, backup)

      response = Faraday.post("#{TELEGRAM_API_URL}/bot#{bot_token}/sendMessage") do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = {
          chat_id: chat_id,
          text: message,
          parse_mode: "HTML"
        }.to_json
      end

      result = JSON.parse(response.body)
      if result["ok"]
        { success: true }
      else
        { success: false, error: result["description"] }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def test_notification
      send_notification(:test)
    end

    private

    def build_telegram_message(event, backup)
      icon = event_icon(event)
      title = event_title(event, backup)

      "#{icon} <b>#{title}</b>\n\n#{build_message(event, backup)}"
    end

    def event_icon(event)
      case event.to_s
      when "success" then "\u2705"  # Green check
      when "failure" then "\u274C"  # Red X
      else "\u2139\uFE0F"  # Info
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
