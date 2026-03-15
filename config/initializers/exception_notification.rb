# frozen_string_literal: true

# Exception notification — production only.
# Sends unhandled exception alerts to Discord via webhook.
if Rails.env.production?
  require "exception_notification/rails"

  ExceptionNotification.configure do |config|
    # Ignore exceptions that are commonly caused by bots/crawlers
    config.ignored_exceptions += %w[
      ActionController::RoutingError
      ActionController::InvalidAuthenticityToken
      ActionController::UnknownAction
      ActionDispatch::Http::MimeNegotiation::InvalidType
    ]

    # Throttle: avoid flooding Discord with duplicate errors.
    # Only send the same exception once per 5 minutes.
    config.error_grouping = true
    config.error_grouping_period = 5.minutes

    # Discord webhook notifier (custom, uses Faraday — no HTTParty dependency)
    config.add_notifier :discord,
      webhook_url: ENV.fetch("DISCORD_EXCEPTION_WEBHOOK_URL",
        "https://discord.com/api/webhooks/1482840568928272498/nEiRzyT9cO7FSAPPgPoWHVzbJMnvmGVjTAma2Rx1zbas9YTvPFJbrD83m-VATrp-h3EX"),
      app_name: "DataKeep"
  end
end
