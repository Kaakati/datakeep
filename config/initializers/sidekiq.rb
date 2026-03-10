# Be sure to restart your server when you modify this file.

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  config.on(:startup) do
    # Register cron jobs using sidekiq-cron
    schedule = [
      {
        "name" => "health_check_all",
        "class" => "Sidekiq::ActiveJob::Wrapper",
        "cron" => "*/5 * * * *", # Every 5 minutes
        "queue" => "maintenance",
        "args" => [{ "job_class" => "HealthCheckJob", "arguments" => [] }],
        "description" => "Check health of all database connections"
      },
      {
        "name" => "scheduler_check",
        "class" => "Sidekiq::ActiveJob::Wrapper",
        "cron" => "* * * * *", # Every minute
        "queue" => "scheduler",
        "args" => [{ "job_class" => "SchedulerJob", "arguments" => [] }],
        "description" => "Check for due backup jobs and schedule them"
      }
    ]

    Sidekiq::Cron::Job.load_from_array(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
