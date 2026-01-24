# Be sure to restart your server when you modify this file.

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    # Register cron jobs using sidekiq-cron
    schedule = [
      {
        "name" => "health_check_all",
        "class" => "HealthCheckJob",
        "cron" => "*/5 * * * *", # Every 5 minutes
        "queue" => "maintenance",
        "description" => "Check health of all database connections"
      }
    ]

    Sidekiq::Cron::Job.load_from_array(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
