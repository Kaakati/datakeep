# DataKeep — Claude Code Guide

## Project Overview

Open-source database backup and monitoring platform built with Ruby on Rails 8.1.
Supports multiple database engines (PostgreSQL implemented; MySQL, MongoDB, MSSQL, etc. planned).
Multi-tenant: each user owns their own databases, backup jobs, storage backends, and notification channels.

## Tech Stack

- **Ruby**: 3.4.7
- **Rails**: 8.1
- **Database**: PostgreSQL (app DB) + PostgreSQL client tools (pg_dump/pg_restore for backups)
- **Background Jobs**: Sidekiq 8 + sidekiq-cron, Redis
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS, TailAdmin dashboard theme
- **Storage**: Local filesystem or AWS S3
- **Auth**: Custom session-based auth with bcrypt (no Devise)
- **Database support**: PostgreSQL (implemented), MySQL / MSSQL / MongoDB / SQLite (planned via adapter pattern)

## Local Development Setup

```bash
bundle install
sudo chmod 0664 log/development.log  # if log file is root-owned
bin/rails db:create db:migrate
bin/rails server         # Terminal 1
bundle exec sidekiq      # Terminal 2
```

Environment variables are loaded from `.env` via `dotenv-rails`.

## Environment Variables (`.env`)

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Rails encryption key |
| `SECRET_KEY_BASE` | Session secret (bypasses credentials.yml.enc) |
| `DATABASE_URL` | Full Postgres connection string |
| `DB_USERNAME` / `DB_PASSWORD` / `DB_HOST` | Used by `config/database.yml` |
| `REDIS_URL` | Redis for Sidekiq + Action Cable (`redis://localhost:6379/0` locally) |

## Authentication

Custom, no Devise. Key files:
- `app/controllers/concerns/authentication.rb` — `current_user`, `logged_in?`, `require_authentication`, `authenticate_user!`
- `app/models/user.rb` — `has_secure_password`, owns all resources
- Session stored in `session[:user_id]`
- All controllers include `Authentication` concern via `ApplicationController`
- Use `allow_unauthenticated_access` to skip auth on specific actions

## Key Architecture

### Database Adapter Factory Pattern

The core extensibility mechanism. New database types are added here — never hardcode DB-specific logic elsewhere.

- `app/services/database_adapter_factory.rb` — registers adapters by type, creates the right adapter for a `DatabaseConfig`
- `app/services/database_adapters/base.rb` — abstract interface all adapters must implement: `backup`, `restore`, `test_connection`, statistics, etc.
- `app/services/database_adapters/postgresql.rb` — PostgreSQL implementation (only one currently)

**Adding a new database type:**
1. Create `app/services/database_adapters/your_db.rb` extending `DatabaseAdapters::Base`
2. Implement all abstract methods
3. Register: `DatabaseAdapterFactory.register(:your_db, DatabaseAdapters::YourDb)`
4. Add the type to `DatabaseConfig` validations/enum

Planned: MySQL, MSSQL, MongoDB, SQLite.

### Service Objects

- `BackupService` — orchestrates backup via adapter
- `RestoreService` — orchestrates restore via adapter
- `SchedulerService` — manages cron scheduling
- `NotificationService` — sends alerts via notification channels
- `HealthCheckService` — runs connectivity/performance checks
- `EncryptionService` — encrypts DB passwords at rest

### Background Jobs

- `BackupExecutionJob` — runs a backup job
- `HealthCheckJob` — runs a health check
- `SchedulerJob` — triggers scheduled backups via sidekiq-cron
- `CleanupJob` — enforces retention policies
- `RestoreExecutionJob` — runs a restore
- `NotificationJob` — sends notifications async

### Models & Relationships

```
User
 ├── DatabaseConfig (has many)
 │    └── HealthCheck (has many)
 ├── StorageBackend (STI: LocalStorage, S3Storage)
 ├── BackupJob
 │    ├── Backup (has many)
 │    └── BackupJobNotificationChannel (join)
 ├── NotificationChannel (STI: SlackChannel, DiscordChannel, TelegramChannel, WebhookChannel, EmailChannel)
 ├── Restore (has many)
 └── AuditLog (has many, nullify on destroy)
```

### Storage Backends (STI)

`StorageBackend` base class with STI:
- `StorageBackends::LocalStorage`
- `StorageBackends::S3Storage`

### Notification Channels (STI)

`NotificationChannel` base class with STI:
- `NotificationChannels::SlackChannel`
- `NotificationChannels::DiscordChannel`
- `NotificationChannels::TelegramChannel`
- `NotificationChannels::WebhookChannel`
- `NotificationChannels::EmailChannel`

## Routes Summary

```
GET  /                          dashboard#index
GET/POST /login                 sessions
DELETE /logout                  sessions#destroy
GET/POST /signup                registrations

resources :database_configs do
  POST :test_connection, :vacuum, :kill_query
  resources :health_checks (index only)
end
resources :health_checks (index only)
resources :storage_backends do
  POST :test_connection
end
resources :backup_jobs do
  POST :run_now, :pause, :resume
  resources :backups (index, show, destroy) do
    POST :restore
    GET  :download
  end
end
resources :backups (index, show)
resources :restores (index, show, new, create)
POST /upload_restore
resources :notification_channels do
  POST :test
end
resources :audit_logs (index, show)
mount Sidekiq::Web => "/sidekiq"
```

## UI Conventions

- TailAdmin dashboard theme — always use its patterns for cards, tables, badges, forms
- Hotwire-first: prefer Turbo Frames/Streams over full page reloads
- WCAG 2.2 Level AA accessibility compliance required
- Follow Rails conventions for naming, MVC separation, and service objects

## Testing

```bash
RAILS_ENV=test bin/rails test
```

## Docker (when needed)

```bash
docker compose up --build
docker compose exec web bin/rails db:create db:migrate
```

Note: `docker-compose.yml` uses `Dockerfile.dev`. The `postgres:latest` service and Redis are required. Ports 5432 and 6379 must be free on the host (or stop local services first).
