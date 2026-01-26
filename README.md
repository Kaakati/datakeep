# DataKeep

**Open-source database backup and monitoring platform for PostgreSQL databases.**

DataKeep provides automated backup scheduling, health monitoring, and backup management through an intuitive web interface built with Ruby on Rails.

![DataKeep Dashboard](DataKeep_Dashboard.png)

## Features

### Database Management
- **Multiple Database Connections** - Connect and manage multiple PostgreSQL databases
- **Connection Testing** - Verify database connectivity before saving configurations
- **Database URL Parsing** - Automatically parse connection strings for quick setup
- **Secure Credentials** - Encrypted storage for database passwords

### Backup Management
- **Scheduled Backups** - Daily, weekly, monthly, or custom cron schedules
- **Manual Backups** - Trigger backups on-demand
- **Backup History** - View and manage all backup records
- **File Deletion** - Delete backup files from storage when removing records
- **Retention Policies** - Automatic cleanup based on retention days

### Storage Backends
- **Local Storage** - Store backups on the local filesystem
- **AWS S3** - Cloud storage with configurable bucket and prefix
- **Multiple Backends** - Configure different storage for different backup jobs

### Health Monitoring
- **Automated Health Checks** - Regular connectivity and performance checks
- **Health Heatmap** - Visual 24-hour health status overview
- **Uptime Tracking** - Monitor database availability percentage
- **Alert System** - Notifications for failed health checks

### User Management
- **Multi-tenant** - Each user manages their own databases and backups
- **Secure Authentication** - bcrypt password hashing
- **Audit Logging** - Track all user actions

## Tech Stack

- **Framework**: Ruby on Rails 8.1
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq with Redis
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **UI Theme**: TailAdmin Dashboard
- **Deployment**: Docker + Kamal

## Requirements

- Docker & Docker Compose (recommended)
- Or: Ruby 3.4.2+, PostgreSQL 14+, Redis 7.0+

## Quick Start with Docker

The easiest way to run DataKeep is with Docker Compose:

### 1. Clone the repository

```bash
git clone https://github.com/Kaakati/datakeep.git
cd datakeep
```

### 2. Start the application

```bash
docker compose up
```

This starts all services:
- **web** - Rails application on [http://localhost:3000](http://localhost:3000)
- **jobs** - Sidekiq background worker
- **db** - PostgreSQL database
- **redis** - Redis for caching and job queues

### 3. Setup the database (first run only)

```bash
docker compose exec web bin/rails db:create db:migrate
```

### 4. Visit the application

Open [http://localhost:3000](http://localhost:3000) in your browser.

### Docker Commands

```bash
# Start in background
docker compose up -d

# View logs
docker compose logs -f web

# Stop services
docker compose down

# Reset database
docker compose exec web bin/rails db:reset

# Run tests
docker compose exec web bin/rails test

# Access Rails console
docker compose exec web bin/rails console
```

## Manual Installation (without Docker)

<details>
<summary>Click to expand manual installation steps</summary>

### 1. Install dependencies

```bash
bundle install
```

### 2. Setup database

```bash
bin/rails db:create db:migrate
```

### 3. Start Redis (required for Sidekiq)

```bash
redis-server
```

### 4. Start the application

```bash
# Terminal 1: Rails server
bin/rails server

# Terminal 2: Sidekiq worker
bundle exec sidekiq
```

</details>

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379/0` |
| `RAILS_ENV` | Environment (development/production/test) | `development` |
| `SECRET_KEY_BASE` | Rails secret key (required in production) | - |

### Storage Backend Configuration

**Local Storage:**
```ruby
{
  path: "/var/backups/datakeep"
}
```

**AWS S3:**
```ruby
{
  bucket: "my-backup-bucket",
  region: "us-east-1",
  access_key_id: "AKIA...",
  secret_access_key: "...",
  prefix: "backups/"
}
```

## Running Tests

```bash
RAILS_ENV=test bin/rails test
```

## Architecture

### Database Adapter Pattern

DataKeep uses a **Factory Pattern** with pluggable database adapters to support multiple database types. This architecture enables easy extension for new database engines (MySQL, MSSQL, MongoDB, etc.).

```
┌─────────────────────────────────────────────────────────────────┐
│                    DatabaseAdapterFactory                        │
│  - Registers adapters by database type                          │
│  - Creates appropriate adapter instance for each DatabaseConfig │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   DatabaseAdapters::Base                         │
│  - Abstract interface defining all database operations          │
│  - Connection testing, backup, restore, statistics              │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│   Postgresql     │ │     MySQL        │ │    MongoDB       │
│   (Implemented)  │ │   (Future)       │ │   (Future)       │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

**Key Components:**

| Component | Location | Purpose |
|-----------|----------|---------|
| `DatabaseAdapterFactory` | `app/services/database_adapter_factory.rb` | Creates adapters based on database type |
| `DatabaseAdapters::Base` | `app/services/database_adapters/base.rb` | Abstract interface for all adapters |
| `DatabaseAdapters::Postgresql` | `app/services/database_adapters/postgresql.rb` | PostgreSQL implementation |
| `BackupService` | `app/services/backup_service.rb` | Unified backup orchestration |
| `RestoreService` | `app/services/restore_service.rb` | Unified restore orchestration |

**Adding a New Database Type:**

1. Create adapter class extending `DatabaseAdapters::Base`
2. Implement all required methods (backup, restore, test_connection, etc.)
3. Register with factory: `DatabaseAdapterFactory.register(:mysql, DatabaseAdapters::Mysql)`

Example:
```ruby
# app/services/database_adapters/mysql.rb
module DatabaseAdapters
  class Mysql < Base
    def backup(output_path:, format: :sql, options: {})
      # mysqldump implementation
    end

    def restore(backup_path:, options: {})
      # mysql import implementation
    end

    # ... implement other required methods
  end
end

DatabaseAdapterFactory.register(:mysql, DatabaseAdapters::Mysql)
```

## Project Structure

```
app/
├── controllers/
│   ├── backups_controller.rb      # Backup management
│   ├── backup_jobs_controller.rb  # Scheduled backup jobs
│   ├── database_configs_controller.rb  # Database connections
│   ├── health_checks_controller.rb     # Health monitoring
│   └── storage_backends_controller.rb  # Storage configuration
├── models/
│   ├── backup.rb                  # Backup records
│   ├── backup_job.rb              # Scheduled jobs
│   ├── database_config.rb         # Database connections
│   ├── health_check.rb            # Health check results
│   ├── storage_backend.rb         # Base storage class (STI)
│   └── storage_backends/
│       ├── local_storage.rb       # Local filesystem
│       └── s3_storage.rb          # AWS S3
├── services/
│   ├── database_adapter_factory.rb    # Factory for database adapters
│   ├── backup_service.rb              # Unified backup orchestration
│   ├── restore_service.rb             # Unified restore orchestration
│   └── database_adapters/
│       ├── base.rb                    # Abstract adapter interface
│       └── postgresql.rb              # PostgreSQL implementation
├── jobs/
│   ├── backup_execution_job.rb    # Execute backups via adapter
│   └── health_check_job.rb        # Execute health checks
└── views/
    └── ...                        # ERB templates with TailAdmin
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/databases` | List all database configurations |
| POST | `/databases` | Create new database configuration |
| GET | `/databases/:id` | Show database details with health/backups |
| POST | `/databases/:id/test_connection` | Test database connectivity |
| GET | `/backup_jobs` | List all backup jobs |
| POST | `/backup_jobs/:id/run_now` | Trigger immediate backup |
| DELETE | `/backup_jobs/:job_id/backups/:id` | Delete backup and file |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Rails conventions
- Write tests for new features
- Use TailAdmin UI patterns for consistency
- Ensure WCAG 2.2 Level AA accessibility compliance

## License

This project is open source and available under the [MIT License](LICENSE).

## Acknowledgments

- [TailAdmin](https://tailadmin.com/) - Dashboard UI template
- [Heroicons](https://heroicons.com/) - Icon set
- [Sidekiq](https://sidekiq.org/) - Background job processing

---

**DataKeep** - Keep your data safe.
