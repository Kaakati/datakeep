# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DataKeep — database backup, sync, and monitoring platform built with Ruby on Rails 8.1.
Multi-tenant: each user owns their own databases, backup jobs, storage backends, sync jobs, and notification channels.
Supports PostgreSQL (implemented); MySQL, MongoDB, MSSQL, SQLite planned via adapter pattern.

## Tech Stack

- **Ruby 3.4.7 / Rails 8.1** with PostgreSQL (app DB)
- **Sidekiq 8 + sidekiq-cron** for background jobs (Redis-backed)
- **Hotwire** (Turbo + Stimulus) + Tailwind CSS + TailAdmin dashboard theme
- **Stripe** for enterprise billing (gem `stripe ~> 13.0`)
- **Custom session-based auth** with bcrypt (no Devise)
- **Propshaft** asset pipeline, **importmap-rails** for JS
- **RSpec** for testing (`bundle exec rspec`)

## Development Commands

```bash
# Local setup
bundle install
bin/rails db:create db:migrate
bin/rails server         # Terminal 1
bundle exec sidekiq      # Terminal 2

# Docker setup (preferred)
docker compose up --build
docker compose exec web bin/rails db:create db:migrate

# Testing
bundle exec rspec                          # Full suite
bundle exec rspec spec/models/user_spec.rb # Single file
bundle exec rspec spec/models/ -e "validates" # By example name

# Linting / Security
bundle exec rubocop
bundle exec brakeman
bundle exec bundler-audit check
```

Environment variables loaded from `.env` via `dotenv-rails`:
`DATABASE_URL`, `REDIS_URL`, `SECRET_KEY_BASE`, `RAILS_MASTER_KEY`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`.

## Authentication & Authorization

Custom auth, no Devise. Key files:
- `app/controllers/concerns/authentication.rb` — `current_user`, `logged_in?`, `require_authentication`, `require_admin`, `authenticate_user!`, `log_in`, `log_out`
- Session stored in `session[:user_id]`
- All controllers include `Authentication` via `ApplicationController`
- Use `allow_unauthenticated_access` to skip auth on specific actions
- `User` has `enum :role, { user: 0, admin: 1 }` — admins access `/admin/*` and Sidekiq Web

### Plan Enforcement
- `app/controllers/concerns/plan_enforcement.rb` — `enforce_plan_limit` class method for before_action
- Free plan has hard limits (1 DB, 1 backup job, 7-day retention, no S3)
- Enterprise plan limits come from `EnterpriseQuote#quote_params`
- Admins bypass all plan limits

## Key Architecture

### Database Adapter Factory Pattern
Core extensibility mechanism — never hardcode DB-specific logic outside adapters.
- `app/services/database_adapter_factory.rb` — registers adapters by type
- `app/services/database_adapters/base.rb` — abstract interface: `backup`, `restore`, `test_connection`, statistics
- `app/services/database_adapters/postgresql.rb` — only implementation so far

Adding a new DB type: create adapter in `database_adapters/`, extend `Base`, register with factory, add type to `DatabaseConfig` validations.

### Admin Namespace
- `Admin::BaseController` inherits `ApplicationController`, adds `before_action :require_admin`
- Routes under `/admin` — dashboard, users CRUD, read-only views for DB configs/backup jobs/backups/audit logs
- Enterprise quote calculator and pricing config management
- Managed storage backends (system-wide, `managed: true`, `user_id: nil`)

### Sync Jobs (Database Replication)
- `SyncJob` — one source DB → many target DBs via `SyncJobTarget` join table
- `SyncService` — orchestrates dump-from-source, restore-to-each-target
- `SyncExecutionJob` — Sidekiq job that runs sync
- Interval-based scheduling (not cron), stored as `interval_minutes`

### VPN Support
- `DatabaseConfig` has optional VPN fields (`vpn_enabled`, `vpn_type`, `vpn_gateway_ip`, `vpn_config_data`)
- `app/services/vpn/` — `Connection`, `ConnectionFactory`, `OpenVpnConnection`, `IpsecConnection`, `NullConnection`
- `app/jobs/concerns/vpn_connectable.rb` — mixin for jobs that need VPN tunnel

### Enterprise Billing (Stripe)
- `app/services/data_keep/stripe/` — `CustomerService`, `SubscriptionService`, `InvoiceService`, `WebhookHandler`
- `app/services/data_keep/enterprise_quote_calculator.rb` — calculates per-DB pricing
- `PricingConfig` model stores configurable pricing tiers in JSONB
- `EnterpriseQuote` tracks quote lifecycle: draft → sent → paid → expired
- Webhook endpoint at `POST /webhooks/stripe` (no auth, no CSRF)

### Storage Backends (STI)
`StorageBackend` base with `StorageBackends::LocalStorage` and `StorageBackends::S3Storage`.
Backup jobs now use a many-to-many join (`BackupJobStorageBackend`) — a job can write to multiple backends.
Managed backends (`managed: true`) are system-wide, created by admins.

### Notification Channels (STI)
`NotificationChannel` base: `SlackChannel`, `DiscordChannel`, `TelegramChannel`, `WebhookChannel`, `EmailChannel`.

### Models & Relationships
```
User (role: user|admin, stripe_customer_id)
 ├── DatabaseConfig (has_many, vpn fields, cached_statistics JSONB)
 │    ├── HealthCheck (has_many)
 │    └── SyncJobTarget (join to SyncJob)
 ├── StorageBackend (STI, has_many)
 ├── BackupJob (has_many)
 │    ├── Backup (has_many)
 │    ├── BackupJobStorageBackend (join, many-to-many)
 │    └── BackupJobNotificationChannel (join)
 ├── SyncJob (has_many)
 │    ├── SyncJobTarget (has_many, each points to a target DatabaseConfig)
 │    └── SyncExecution (has_many)
 ├── NotificationChannel (STI, has_many)
 ├── EnterpriseQuote (has_many)
 ├── Restore (has_many)
 └── AuditLog (has_many, nullify on destroy)

PricingConfig (standalone, admin-managed)
```

### Background Jobs
- `BackupExecutionJob` — runs backup, supports VPN via `VpnConnectable`
- `SyncExecutionJob` — runs database sync
- `RestoreExecutionJob` — runs restore
- `HealthCheckJob` — connectivity/performance checks
- `SchedulerJob` — triggers scheduled backups via sidekiq-cron
- `StripeInvoiceJob` — async Stripe invoice operations
- `CleanupJob` — retention policy enforcement
- `NotificationJob` — async notification delivery

## UI Conventions

- TailAdmin dashboard theme — use its patterns for cards, tables, badges, forms
- Hotwire-first: prefer Turbo Frames/Streams over full page reloads
- Stimulus controllers in `app/javascript/controllers/`
- WCAG 2.2 Level AA accessibility compliance required
- **Full-width layout**: The layout wrapper uses `w-full` — never add `max-w-screen-*` or `mx-auto` to page-level containers. Views should use the full available width. Only constrain width on individual UI elements (forms, modals) where readability requires it.

## Docker Notes

`docker-compose.yml` uses `Dockerfile.dev`. Exposes: web on 3000, Postgres on 5430 (host), Redis on 6370 (host).
The `jobs` service has `NET_ADMIN`/`NET_RAW` capabilities and `/dev/net/tun` for VPN support.
