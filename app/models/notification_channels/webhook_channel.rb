# frozen_string_literal: true

module NotificationChannels
  class WebhookChannel < NotificationChannel
    validates :encrypted_config, presence: true

    def url
      config[:url]
    end

    def headers
      config[:headers] || {}
    end

    def http_method
      (config[:method] || "POST").upcase
    end

    def send_notification(event, backup = nil)
      payload = build_webhook_payload(event, backup)

      response = Faraday.new.send(http_method.downcase.to_sym, url) do |req|
        req.headers["Content-Type"] = "application/json"
        headers.each { |key, value| req.headers[key.to_s] = value }
        req.body = payload.to_json
      end

      if response.success?
        { success: true }
      else
        { success: false, error: "Webhook returned #{response.status}" }
      end
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def test_notification
      send_notification(:test)
    end

    private

    def build_webhook_payload(event, backup)
      {
        event: event.to_s,
        timestamp: Time.current.iso8601,
        message: build_message(event, backup),
        backup: backup ? backup_details(backup) : nil
      }.compact
    end

    def backup_details(backup)
      {
        id: backup.id,
        database_name: backup.database_name,
        status: backup.status,
        file_name: backup.file_name,
        file_size: backup.file_size,
        duration_seconds: backup.duration,
        started_at: backup.started_at&.iso8601,
        completed_at: backup.completed_at&.iso8601,
        error_message: backup.error_message
      }.compact
    end
  end
end
