# Be sure to restart your server when you modify this file.

require "sidekiq-failures"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Track all failed jobs in the Failures tab (default: tracks all)
  config[:failures_default_mode] = :all

  # Report failed jobs to exception notifier (Discord)
  config.death_handlers << ->(job, ex) do
    ExceptionNotifier.notify_exception(
      ex,
      data: {
        job_class: job["class"],
        job_id: job["jid"],
        queue: job["queue"],
        args: job["args"],
        retried: job["retry_count"].to_i,
        error_class: job["error_class"],
        failed_at: job["failed_at"]
      }
    )
  end

  config.on(:startup) do
    schedule = YAML.load_file(Rails.root.join("config", "sidekiq_cron.yml"))
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
