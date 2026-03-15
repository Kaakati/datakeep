# frozen_string_literal: true

module ExceptionNotifier
  class DiscordNotifier
    MAX_CONTENT_LENGTH = 2000

    def initialize(options)
      @webhook_url = options.fetch(:webhook_url)
      @app_name = options.fetch(:app_name, "DataKeep")
    end

    def call(exception, options = {})
      return if @webhook_url.blank?

      env = options[:env]
      request = ActionDispatch::Request.new(env) if env

      message = build_message(exception, request)

      Faraday.post(@webhook_url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = { content: message }.to_json
      end
    rescue => e
      Rails.logger.error("[ExceptionNotifier::DiscordNotifier] Failed to send notification: #{e.message}")
    end

    private

    def build_message(exception, request = nil)
      parts = []
      parts << "**#{@app_name} Exception**"
      parts << "**Error:** `#{exception.class}: #{exception.message}`"
      parts << "**Host:** `#{Socket.gethostname}`"
      parts << "**Time:** #{Time.current.iso8601}"

      if request
        parts << "**URL:** `#{request.method} #{request.url}`"
        parts << "**IP:** `#{request.remote_ip}`"
      end

      if exception.backtrace.present?
        trace = exception.backtrace.first(5).join("\n")
        parts << "**Backtrace:**\n```\n#{trace}\n```"
      end

      message = parts.join("\n")
      message.truncate(MAX_CONTENT_LENGTH)
    end
  end
end
