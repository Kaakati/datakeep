# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_10_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.string "ip_address"
    t.integer "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_audit_logs_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "backup_job_notification_channels", force: :cascade do |t|
    t.bigint "backup_job_id", null: false
    t.datetime "created_at", null: false
    t.bigint "notification_channel_id", null: false
    t.datetime "updated_at", null: false
    t.index ["backup_job_id", "notification_channel_id"], name: "idx_backup_job_notification_channel_unique", unique: true
    t.index ["backup_job_id"], name: "index_backup_job_notification_channels_on_backup_job_id"
    t.index ["notification_channel_id"], name: "idx_on_notification_channel_id_848a00b350"
  end

  create_table "backup_jobs", force: :cascade do |t|
    t.boolean "compression", default: true, null: false
    t.datetime "created_at", null: false
    t.string "cron_expression"
    t.bigint "database_config_id", null: false
    t.boolean "enabled", default: true, null: false
    t.boolean "encryption", default: false, null: false
    t.datetime "last_run_at"
    t.string "name", null: false
    t.datetime "next_run_at"
    t.integer "retention_days", default: 30, null: false
    t.string "schedule_type", default: "daily", null: false
    t.string "status", default: "idle", null: false
    t.bigint "storage_backend_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["database_config_id"], name: "index_backup_jobs_on_database_config_id"
    t.index ["enabled"], name: "index_backup_jobs_on_enabled"
    t.index ["next_run_at"], name: "index_backup_jobs_on_next_run_at"
    t.index ["storage_backend_id"], name: "index_backup_jobs_on_storage_backend_id"
    t.index ["user_id", "name"], name: "index_backup_jobs_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_backup_jobs_on_user_id"
  end

  create_table "backups", force: :cascade do |t|
    t.bigint "backup_job_id", null: false
    t.string "checksum"
    t.datetime "completed_at"
    t.boolean "compressed", default: false, null: false
    t.datetime "created_at", null: false
    t.string "database_name"
    t.boolean "encrypted", default: false, null: false
    t.text "error_message"
    t.string "file_name", null: false
    t.string "file_path"
    t.bigint "file_size"
    t.string "pg_version"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.bigint "storage_backend_id", null: false
    t.datetime "updated_at", null: false
    t.index ["backup_job_id"], name: "index_backups_on_backup_job_id"
    t.index ["created_at"], name: "index_backups_on_created_at"
    t.index ["status"], name: "index_backups_on_status"
    t.index ["storage_backend_id"], name: "index_backups_on_storage_backend_id"
  end

  create_table "database_configs", force: :cascade do |t|
    t.jsonb "cached_statistics"
    t.datetime "created_at", null: false
    t.string "database_name", null: false
    t.string "database_type", default: "postgresql", null: false
    t.text "encrypted_password"
    t.string "health_status", default: "unknown"
    t.string "host", null: false
    t.datetime "last_health_check_at"
    t.string "name", null: false
    t.string "pg_version"
    t.integer "port", default: 5432, null: false
    t.string "ssl_mode", default: "prefer"
    t.datetime "statistics_updated_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "username", null: false
    t.text "vpn_config_data"
    t.boolean "vpn_enabled", default: false, null: false
    t.string "vpn_gateway_ip"
    t.string "vpn_tunnel_name"
    t.string "vpn_type"
    t.index ["database_type"], name: "index_database_configs_on_database_type"
    t.index ["user_id", "name"], name: "index_database_configs_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_database_configs_on_user_id"
    t.index ["vpn_enabled"], name: "index_database_configs_on_vpn_enabled"
  end

  create_table "health_checks", force: :cascade do |t|
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.bigint "database_config_id", null: false
    t.text "error_message"
    t.integer "response_time_ms"
    t.string "status", default: "unknown", null: false
    t.datetime "updated_at", null: false
    t.index ["checked_at"], name: "index_health_checks_on_checked_at"
    t.index ["database_config_id", "checked_at"], name: "index_health_checks_on_database_config_id_and_checked_at"
    t.index ["database_config_id"], name: "index_health_checks_on_database_config_id"
    t.index ["status"], name: "index_health_checks_on_status"
  end

  create_table "notification_channels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.text "encrypted_config"
    t.string "name", null: false
    t.boolean "notify_on_failure", default: true, null: false
    t.boolean "notify_on_success", default: false, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_notification_channels_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_notification_channels_on_user_id"
  end

  create_table "restores", force: :cascade do |t|
    t.bigint "backup_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "database_config_id", null: false
    t.text "error_message"
    t.string "file_path"
    t.datetime "started_at"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["backup_id"], name: "index_restores_on_backup_id"
    t.index ["database_config_id"], name: "index_restores_on_database_config_id"
    t.index ["status"], name: "index_restores_on_status"
    t.index ["user_id"], name: "index_restores_on_user_id"
  end

  create_table "storage_backends", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_config"
    t.boolean "is_default", default: false, null: false
    t.string "name", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_storage_backends_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_storage_backends_on_user_id"
  end

  create_table "sync_executions", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.bigint "sync_job_id", null: false
    t.integer "targets_count", default: 0
    t.integer "targets_succeeded", default: 0
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sync_executions_on_created_at"
    t.index ["status"], name: "index_sync_executions_on_status"
    t.index ["sync_job_id"], name: "index_sync_executions_on_sync_job_id"
  end

  create_table "sync_job_targets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "database_config_id", null: false
    t.bigint "sync_job_id", null: false
    t.datetime "updated_at", null: false
    t.index ["database_config_id"], name: "index_sync_job_targets_on_database_config_id"
    t.index ["sync_job_id", "database_config_id"], name: "index_sync_job_targets_on_sync_job_id_and_database_config_id", unique: true
    t.index ["sync_job_id"], name: "index_sync_job_targets_on_sync_job_id"
  end

  create_table "sync_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.integer "interval_minutes", default: 60, null: false
    t.datetime "last_run_at"
    t.string "name", null: false
    t.datetime "next_run_at"
    t.bigint "source_database_config_id", null: false
    t.string "status", default: "idle", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["enabled"], name: "index_sync_jobs_on_enabled"
    t.index ["next_run_at"], name: "index_sync_jobs_on_next_run_at"
    t.index ["source_database_config_id"], name: "index_sync_jobs_on_source_database_config_id"
    t.index ["user_id", "name"], name: "index_sync_jobs_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_sync_jobs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "backup_job_notification_channels", "backup_jobs"
  add_foreign_key "backup_job_notification_channels", "notification_channels"
  add_foreign_key "backup_jobs", "database_configs"
  add_foreign_key "backup_jobs", "storage_backends"
  add_foreign_key "backup_jobs", "users"
  add_foreign_key "backups", "backup_jobs"
  add_foreign_key "backups", "storage_backends"
  add_foreign_key "database_configs", "users"
  add_foreign_key "health_checks", "database_configs"
  add_foreign_key "notification_channels", "users"
  add_foreign_key "restores", "backups"
  add_foreign_key "restores", "database_configs"
  add_foreign_key "restores", "users"
  add_foreign_key "storage_backends", "users"
  add_foreign_key "sync_executions", "sync_jobs"
  add_foreign_key "sync_job_targets", "database_configs"
  add_foreign_key "sync_job_targets", "sync_jobs"
  add_foreign_key "sync_jobs", "database_configs", column: "source_database_config_id"
  add_foreign_key "sync_jobs", "users"
end
