# Be sure to restart your server when you modify this file.

require "sidekiq-failures"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Track all failed jobs in the Failures tab (default: tracks all)
  config[:failures_default_mode] = :all

  config.on(:startup) do
    schedule = YAML.load_file(Rails.root.join("config", "sidekiq_cron.yml"))
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
