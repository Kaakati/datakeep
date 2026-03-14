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

ActiveRecord::Schema[8.1].define(version: 2026_03_15_014524) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "postgis"

  create_table "account_domains", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "subdomain", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_account_domains_on_account_id"
    t.index ["subdomain", "domain"], name: "index_account_domains_on_subdomain_and_domain", unique: true
  end

  create_table "account_integration_credentials", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "credentials", default: {}, null: false
    t.bigint "integration_id", null: false
    t.text "last_test_error"
    t.string "last_test_status"
    t.datetime "last_tested_at"
    t.datetime "last_used_at"
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.float "priority", default: 0.0
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.index ["account_id", "integration_id"], name: "index_account_creds_on_account_and_integration", unique: true
    t.index ["account_id", "status"], name: "index_account_integration_credentials_on_account_id_and_status"
    t.index ["account_id"], name: "index_account_integration_credentials_on_account_id"
    t.index ["credentials"], name: "index_account_integration_credentials_on_credentials", using: :gin
    t.index ["integration_id"], name: "index_account_integration_credentials_on_integration_id"
    t.index ["last_used_at"], name: "index_account_integration_credentials_on_last_used_at"
  end

  create_table "account_integrations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.jsonb "credentials", default: {}, null: false
    t.integer "integration_type", null: false
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.float "priority", default: 0.0
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "integration_type"], name: "index_account_integrations_on_account_and_type", unique: true
    t.index ["account_id", "status"], name: "index_account_integrations_on_account_id_and_status"
    t.index ["account_id"], name: "index_account_integrations_on_account_id"
    t.index ["category"], name: "index_account_integrations_on_category"
    t.index ["credentials"], name: "index_account_integrations_on_credentials", using: :gin
  end

  create_table "account_status_changes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "admin_id", null: false
    t.datetime "created_at", null: false
    t.string "from_status", null: false
    t.text "reason"
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_account_status_changes_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_account_status_changes_on_account_id"
    t.index ["admin_id"], name: "index_account_status_changes_on_admin_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.jsonb "cached_primary_shades", default: {}
    t.jsonb "cached_primary_shades_dark", default: {}
    t.jsonb "cached_secondary_shades", default: {}
    t.jsonb "cached_secondary_shades_dark", default: {}
    t.integer "client_id"
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.integer "currency", default: 0, null: false
    t.string "domain", null: false
    t.datetime "email_verification_sent_at"
    t.string "email_verification_token"
    t.boolean "email_verified", default: false, null: false
    t.string "facebook_url"
    t.string "instagram_url"
    t.string "linkedin_url"
    t.text "meta_description_ar"
    t.text "meta_description_en"
    t.string "meta_keywords_ar"
    t.string "meta_keywords_en"
    t.string "meta_title_ar"
    t.string "meta_title_en"
    t.string "og_image_url"
    t.string "primary_color", default: "#0044ff", null: false
    t.string "primary_color_dark", default: "#5c9aff", null: false
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.string "secondary_color", default: "#066AFE", null: false
    t.string "secondary_color_dark", default: "#5c9aff", null: false
    t.integer "status"
    t.string "subdomain", null: false
    t.string "text_color", default: "#010723", null: false
    t.string "text_color_dark", default: "#f3f4f6", null: false
    t.datetime "trial_expires"
    t.datetime "updated_at", null: false
    t.string "x_url"
    t.string "youtube_url"
    t.index ["approved_by_id"], name: "index_accounts_on_approved_by_id"
    t.index ["country_id"], name: "index_accounts_on_country_id"
    t.index ["currency"], name: "index_accounts_on_currency"
    t.index ["email_verification_token"], name: "index_accounts_on_email_verification_token", unique: true
    t.index ["primary_color"], name: "index_accounts_on_primary_color"
    t.index ["subdomain", "domain"], name: "index_accounts_on_subdomain_and_domain", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

# Could not dump table "addresses" because of following StandardError
#   Unknown type 'geography' for column 'location'


  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "mobile"
    t.string "password_digest"
    t.integer "role", default: 0
    t.string "theme_preference", default: "light", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["theme_preference"], name: "index_admins_on_theme_preference"
  end

  create_table "aisles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "identifier"
    t.string "letter"
    t.string "name"
    t.integer "number"
    t.bigint "room_id", null: false
    t.integer "start_side"
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_aisles_on_room_id"
  end

  create_table "android_app_versions", force: :cascade do |t|
    t.bigint "android_app_id", null: false
    t.string "apk_file"
    t.integer "build_number", null: false
    t.datetime "created_at", null: false
    t.integer "download_count", default: 0, null: false
    t.string "download_token"
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.string "version_number", null: false
    t.index ["android_app_id", "version_number", "build_number"], name: "idx_app_version_build_unique", unique: true
    t.index ["android_app_id"], name: "index_android_app_versions_on_android_app_id"
    t.index ["created_at"], name: "index_android_app_versions_on_created_at"
    t.index ["download_token"], name: "index_android_app_versions_on_download_token", unique: true
    t.index ["published_at"], name: "index_android_app_versions_on_published_at"
  end

  create_table "android_apps", force: :cascade do |t|
    t.text "app_description"
    t.string "app_icon"
    t.string "app_name", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["app_name"], name: "index_android_apps_on_app_name"
    t.index ["created_at"], name: "index_android_apps_on_created_at"
    t.index ["is_active"], name: "index_android_apps_on_is_active"
  end

  create_table "archived_audits", force: :cascade do |t|
    t.bigint "account_id"
    t.string "action"
    t.datetime "archived_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "associated_id"
    t.string "associated_type"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.jsonb "audited_changes"
    t.string "browser_name", limit: 100
    t.string "browser_version", limit: 50
    t.string "comment"
    t.string "device_type", limit: 50
    t.string "geo_city", limit: 100
    t.string "geo_country", limit: 100
    t.string "geo_country_code", limit: 10
    t.bigint "original_audit_id", null: false
    t.datetime "original_created_at", null: false
    t.string "os_name", limit: 100
    t.string "os_version", limit: 50
    t.string "remote_address"
    t.string "request_uuid"
    t.text "user_agent"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["account_id"], name: "index_archived_audits_on_account_id"
    t.index ["auditable_type", "auditable_id"], name: "index_archived_audits_on_auditable"
    t.index ["original_audit_id"], name: "index_archived_audits_on_original_audit_id", unique: true
    t.index ["original_created_at"], name: "index_archived_audits_on_original_created_at"
    t.index ["user_type", "user_id"], name: "index_archived_audits_on_user"
  end

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

  create_table "audits", force: :cascade do |t|
    t.bigint "account_id"
    t.string "action"
    t.bigint "associated_id"
    t.string "associated_type"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.jsonb "audited_changes"
    t.string "browser_name", limit: 100
    t.string "browser_version", limit: 50
    t.string "comment"
    t.datetime "created_at"
    t.string "device_type", limit: 50
    t.string "geo_city", limit: 100
    t.string "geo_country", limit: 100
    t.string "geo_country_code", limit: 10
    t.string "os_name", limit: 100
    t.string "os_version", limit: 50
    t.string "remote_address"
    t.string "request_uuid"
    t.text "user_agent"
    t.bigint "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["account_id", "created_at"], name: "index_audits_on_account_and_created_at"
    t.index ["account_id"], name: "index_audits_on_account_id"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["device_type"], name: "index_audits_on_device_type"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
    t.index ["user_type", "user_id", "created_at"], name: "index_audits_on_user_and_created_at"
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

  create_table "backup_job_storage_backends", force: :cascade do |t|
    t.bigint "backup_job_id", null: false
    t.datetime "created_at", null: false
    t.bigint "storage_backend_id", null: false
    t.datetime "updated_at", null: false
    t.index ["backup_job_id", "storage_backend_id"], name: "idx_backup_job_storage_backend_unique", unique: true
    t.index ["backup_job_id"], name: "index_backup_job_storage_backends_on_backup_job_id"
    t.index ["storage_backend_id"], name: "index_backup_job_storage_backends_on_storage_backend_id"
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
    t.bigint "storage_backend_id"
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

  create_table "bays", force: :cascade do |t|
    t.bigint "aisle_id", null: false
    t.integer "bay_type"
    t.datetime "created_at", null: false
    t.string "identifier"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["aisle_id"], name: "index_bays_on_aisle_id"
  end

  create_table "branches", force: :cascade do |t|
    t.integer "account_id"
    t.integer "branch_type", default: 0
    t.integer "city_id"
    t.time "close_time", default: "2000-01-01 21:00:00"
    t.datetime "created_at", null: false
    t.string "identifier"
    t.float "latitude", default: 0.0
    t.integer "locality_id"
    t.float "longitude", default: 0.0
    t.integer "merchant_id"
    t.string "name_ar", null: false
    t.string "name_en", null: false
    t.time "open_time", default: "2000-01-01 09:00:00"
    t.integer "serving_capacity", default: 30
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_branches_on_account_id"
    t.index ["merchant_id", "branch_type"], name: "index_branches_on_merchant_and_type"
    t.index ["merchant_id"], name: "index_branches_on_merchant_id"
  end

# Could not dump table "bundles" because of following StandardError
#   Unknown type 'geography' for column 'pickup_location'


  create_table "capacities", force: :cascade do |t|
    t.integer "amount"
    t.bigint "capacityable_id", null: false
    t.string "capacityable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["capacityable_type", "capacityable_id"], name: "index_capacities_on_capacityable"
  end

  create_table "carrier_certifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "carrier_id", null: false
    t.string "certificate_number"
    t.bigint "certification_id", null: false
    t.datetime "created_at", null: false
    t.date "expiry_date"
    t.date "issued_date"
    t.string "issuing_authority"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.boolean "verified"
    t.datetime "verified_at"
    t.integer "verified_by_id"
    t.index ["account_id"], name: "index_carrier_certifications_on_account_id"
    t.index ["carrier_id"], name: "index_carrier_certifications_on_carrier_id"
    t.index ["certification_id"], name: "index_carrier_certifications_on_certification_id"
  end

  create_table "carrier_documents", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "carrier_id", null: false
    t.datetime "created_at", null: false
    t.integer "document_category"
    t.integer "document_type"
    t.date "expiry_date"
    t.date "issued_date"
    t.text "notes"
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.integer "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "uploaded_by_id"
    t.index ["account_id"], name: "index_carrier_documents_on_account_id"
    t.index ["carrier_id"], name: "index_carrier_documents_on_carrier_id"
  end

# Could not dump table "carrier_locations" because of following StandardError
#   Unknown type 'geography' for column 'location'


  create_table "carrier_reward_schemes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "base_per_order", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.decimal "first_task_base_fare", precision: 10, scale: 2
    t.decimal "fixed_amount", precision: 10, scale: 2
    t.boolean "is_active", default: true, null: false
    t.string "name", default: "Default Reward Scheme", null: false
    t.integer "pricing_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "is_active"], name: "index_carrier_reward_schemes_on_account_id_and_is_active"
    t.index ["account_id"], name: "index_carrier_reward_schemes_on_account_id"
    t.index ["account_id"], name: "index_carrier_reward_schemes_on_account_id_unique", unique: true
    t.index ["is_active"], name: "index_carrier_reward_schemes_on_is_active"
  end

  create_table "carrier_trainings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "carrier_id", null: false
    t.string "certificate_number"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "expiry_date"
    t.string "instructor_name"
    t.text "notes"
    t.integer "score"
    t.datetime "started_at"
    t.integer "status"
    t.bigint "training_module_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_carrier_trainings_on_account_id"
    t.index ["carrier_id"], name: "index_carrier_trainings_on_carrier_id"
    t.index ["training_module_id"], name: "index_carrier_trainings_on_training_module_id"
  end

# Could not dump table "carriers" because of following StandardError
#   Unknown type 'geography' for column 'home_location'


  create_table "carriers_localities", id: false, force: :cascade do |t|
    t.bigint "carrier_id", null: false
    t.bigint "locality_id", null: false
    t.index ["carrier_id", "locality_id"], name: "index_carriers_localities_on_carrier_id_and_locality_id"
    t.index ["locality_id", "carrier_id"], name: "index_carriers_localities_on_locality_id_and_carrier_id"
  end

  create_table "carriers_zones", id: false, force: :cascade do |t|
    t.bigint "carrier_id"
    t.bigint "zone_id"
    t.index ["carrier_id"], name: "index_carriers_zones_on_carrier_id"
    t.index ["zone_id"], name: "index_carriers_zones_on_zone_id"
  end

  create_table "certifications", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "category"
    t.string "code"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "issuing_authority"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_certifications_on_account_id"
  end

  create_table "cities", force: :cascade do |t|
    t.bigint "country_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true
    t.float "latitude"
    t.float "longitude"
    t.string "name_ar"
    t.string "name_en"
    t.string "name_es"
    t.string "name_fr"
    t.string "name_ru"
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_cities_on_country_id"
    t.index ["name_ar"], name: "idx_cities_name_ar_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["name_en"], name: "idx_cities_name_en_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "city_shipping_companies", force: :cascade do |t|
    t.bigint "city_id", null: false
    t.datetime "created_at", null: false
    t.bigint "shipping_company_id", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id", "shipping_company_id"], name: "idx_on_city_id_shipping_company_id_aabd6c4bfe", unique: true
    t.index ["city_id"], name: "index_city_shipping_companies_on_city_id"
    t.index ["shipping_company_id"], name: "index_city_shipping_companies_on_shipping_company_id"
  end

  create_table "client_login_events", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "browser_name", limit: 100
    t.string "browser_version", limit: 50
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.string "device_type", limit: 50
    t.string "failure_reason", limit: 255
    t.string "geo_city", limit: 100
    t.string "geo_country", limit: 100
    t.string "geo_country_code", limit: 10
    t.string "ip_address", limit: 45
    t.integer "login_result", default: 0, null: false
    t.string "os_name", limit: 100
    t.string "os_version", limit: 50
    t.string "session_id", limit: 100
    t.text "user_agent"
    t.index ["account_id", "created_at"], name: "index_login_events_on_account_and_created_at"
    t.index ["account_id"], name: "index_client_login_events_on_account_id"
    t.index ["client_id", "created_at"], name: "index_login_events_on_client_and_created_at"
    t.index ["client_id"], name: "index_client_login_events_on_client_id"
    t.index ["ip_address"], name: "index_login_events_on_ip_address"
    t.index ["login_result"], name: "index_login_events_on_login_result"
  end

  create_table "client_request_logs", force: :cascade do |t|
    t.bigint "account_id"
    t.string "action"
    t.bigint "client_id"
    t.string "client_type"
    t.string "controller"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "params", default: {}
    t.string "path", null: false
    t.string "request_method", null: false
    t.float "response_time_ms"
    t.string "session_id"
    t.integer "status_code"
    t.string "user_agent"
    t.index ["account_id", "created_at"], name: "index_client_request_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_client_request_logs_on_account_id"
    t.index ["client_type", "client_id"], name: "index_client_request_logs_on_client"
    t.index ["created_at"], name: "index_client_request_logs_on_created_at"
    t.index ["path"], name: "index_client_request_logs_on_path"
  end

  create_table "clients", force: :cascade do |t|
    t.string "address_ar"
    t.text "address_en"
    t.string "address_fr"
    t.string "address_ru"
    t.string "billing_email"
    t.integer "city_id"
    t.string "company_name_ar"
    t.string "company_name_en"
    t.string "company_name_es"
    t.string "company_name_fr"
    t.string "company_name_ru"
    t.integer "country_id"
    t.string "cr_number"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "facebook_url"
    t.string "hotline_number"
    t.string "instagram_url"
    t.string "linkedin_url"
    t.string "magic_link_token"
    t.datetime "magic_link_token_sent_at"
    t.string "manager"
    t.string "manager_contact"
    t.string "mobile"
    t.string "password_digest"
    t.string "phone"
    t.string "primary_color"
    t.jsonb "public_information"
    t.string "secondary_color"
    t.string "stripe_id"
    t.string "stripe_subscription_id"
    t.string "text_color"
    t.string "theme_preference", default: "light", null: false
    t.string "twitter_url"
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "vat_number"
    t.index ["magic_link_token"], name: "index_clients_on_magic_link_token", unique: true
    t.index ["theme_preference"], name: "index_clients_on_theme_preference"
  end

  create_table "countries", force: :cascade do |t|
    t.string "country_code"
    t.datetime "created_at", null: false
    t.string "currency"
    t.integer "dial_code"
    t.boolean "is_active", default: true
    t.string "name_ar"
    t.string "name_en"
    t.string "name_es"
    t.string "name_fr"
    t.string "name_ru"
    t.float "tax_amount"
    t.datetime "updated_at", null: false
  end

  create_table "database_configs", force: :cascade do |t|
    t.jsonb "cached_statistics"
    t.datetime "created_at", null: false
    t.string "database_name", null: false
    t.string "database_type", default: "postgresql", null: false
    t.text "encrypted_password"
    t.bigint "enterprise_quote_id"
    t.string "health_status", default: "unknown"
    t.string "host", null: false
    t.datetime "last_health_check_at"
    t.string "name", null: false
    t.string "pg_version"
    t.integer "port", default: 5432, null: false
    t.integer "quote_database_index"
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
    t.index ["enterprise_quote_id", "quote_database_index"], name: "idx_database_configs_on_quote_slot", unique: true, where: "(enterprise_quote_id IS NOT NULL)"
    t.index ["enterprise_quote_id"], name: "index_database_configs_on_enterprise_quote_id"
    t.index ["user_id", "name"], name: "index_database_configs_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_database_configs_on_user_id"
    t.index ["vpn_enabled"], name: "index_database_configs_on_vpn_enabled"
  end

  create_table "depots", force: :cascade do |t|
    t.integer "account_id"
    t.string "address_line1"
    t.integer "city_id"
    t.string "code"
    t.datetime "created_at", null: false
    t.integer "depot_type", default: 0
    t.string "district"
    t.string "identifier"
    t.float "latitude"
    t.float "longitude"
    t.string "manager"
    t.string "mobile"
    t.string "name_ar"
    t.string "name_en"
    t.string "postal_code"
    t.integer "role", default: 0
    t.integer "service_type", default: 0
    t.string "short_code"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["account_id", "code"], name: "index_depots_on_account_id_and_code", unique: true
    t.index ["account_id", "identifier"], name: "index_depots_on_account_id_and_identifier"
    t.index ["account_id", "short_code"], name: "index_depots_on_account_id_and_short_code", unique: true
    t.index ["city_id"], name: "index_depots_on_city_id"
  end

  create_table "devices", force: :cascade do |t|
    t.string "app_build"
    t.string "app_version"
    t.string "brand"
    t.bigint "carrier_id", null: false
    t.datetime "created_at", null: false
    t.string "device_id"
    t.datetime "last_seen_at"
    t.string "model"
    t.string "os"
    t.string "os_version"
    t.text "push_token"
    t.datetime "updated_at", null: false
    t.index ["carrier_id"], name: "index_devices_on_carrier_id"
  end

  create_table "distance_tiers", force: :cascade do |t|
    t.bigint "carrier_reward_scheme_id", null: false
    t.datetime "created_at", null: false
    t.decimal "from_km", precision: 10, scale: 2, null: false
    t.decimal "rate_per_km", precision: 10, scale: 2, null: false
    t.decimal "to_km", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["carrier_reward_scheme_id", "from_km", "to_km"], name: "index_distance_tiers_on_scheme_and_range"
    t.index ["carrier_reward_scheme_id"], name: "index_distance_tiers_on_carrier_reward_scheme_id"
    t.check_constraint "from_km >= 0::numeric AND (to_km IS NULL OR to_km >= 0::numeric) AND rate_per_km >= 0::numeric", name: "check_distance_tier_positive"
    t.check_constraint "to_km IS NULL OR to_km > from_km", name: "check_distance_tier_range"
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.integer "depot_id"
    t.string "email"
    t.string "first_name"
    t.string "id_number"
    t.string "last_name"
    t.string "mobile"
    t.integer "nationality_id"
    t.string "passport_number"
    t.integer "role"
    t.integer "status"
    t.datetime "updated_at", null: false
  end

  create_table "enterprise_quotes", force: :cascade do |t|
    t.bigint "admin_user_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "usd"
    t.float "discount_percent", default: 0.0
    t.datetime "expires_at"
    t.jsonb "line_items_snapshot", null: false
    t.datetime "paid_at"
    t.jsonb "quote_params", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.string "stripe_coupon_id"
    t.string "stripe_hosted_invoice_url"
    t.string "stripe_invoice_id"
    t.string "stripe_subscription_id"
    t.integer "total_monthly_cents", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_user_id"], name: "index_enterprise_quotes_on_admin_user_id"
    t.index ["status"], name: "index_enterprise_quotes_on_status"
    t.index ["stripe_invoice_id"], name: "index_enterprise_quotes_on_stripe_invoice_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_enterprise_quotes_on_stripe_subscription_id", unique: true
    t.index ["user_id"], name: "index_enterprise_quotes_on_user_id"
  end

  create_table "failure_reasons", force: :cascade do |t|
    t.integer "account_id"
    t.integer "client_id"
    t.datetime "created_at", null: false
    t.text "message"
    t.text "message_locale"
    t.integer "status"
    t.string "title"
    t.string "title_locale"
    t.datetime "updated_at", null: false
  end

  create_table "fleet_assignments", force: :cascade do |t|
    t.bigint "bundle_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "fleet_id", null: false
    t.datetime "started_at"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["bundle_id"], name: "index_fleet_assignments_on_bundle_id"
    t.index ["fleet_id", "status"], name: "index_fleet_assignments_on_fleet_id_and_status"
    t.index ["fleet_id"], name: "index_fleet_assignments_on_fleet_id"
    t.index ["vehicle_id", "status"], name: "index_fleet_assignments_on_vehicle_id_and_status"
    t.index ["vehicle_id"], name: "index_fleet_assignments_on_vehicle_id"
  end

  create_table "fleet_merchants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "fleet_id", null: false
    t.bigint "merchant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["fleet_id", "merchant_id"], name: "index_fleet_merchants_on_fleet_id_and_merchant_id", unique: true
    t.index ["fleet_id"], name: "index_fleet_merchants_on_fleet_id"
    t.index ["merchant_id"], name: "index_fleet_merchants_on_merchant_id"
  end

  create_table "fleets", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "capacity", default: 30
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "fleet_type", default: 0
    t.string "name"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.index ["account_id", "fleet_type"], name: "index_fleets_on_account_id_and_fleet_type"
    t.index ["account_id"], name: "index_fleets_on_account_id"
  end

  create_table "forwarding_rules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "account_integration_id", null: false
    t.datetime "created_at", null: false
    t.integer "current_count", default: 0, null: false
    t.bigint "destination_city_id"
    t.boolean "is_active", default: true, null: false
    t.bigint "merchant_id"
    t.string "name", null: false
    t.bigint "origin_city_id"
    t.integer "priority", default: 0, null: false
    t.integer "quantity_limit", null: false
    t.string "reference_tag", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "account_integration_id"], name: "index_forwarding_rules_on_account_integration"
    t.index ["account_id", "is_active"], name: "index_forwarding_rules_on_account_active"
    t.index ["account_id", "priority"], name: "index_forwarding_rules_on_account_priority"
    t.index ["account_id", "reference_tag"], name: "index_forwarding_rules_on_account_tag", unique: true
    t.index ["destination_city_id"], name: "index_forwarding_rules_on_destination_city"
    t.index ["merchant_id"], name: "index_forwarding_rules_on_merchant"
    t.index ["origin_city_id"], name: "index_forwarding_rules_on_origin_city"
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

  create_table "integrations", force: :cascade do |t|
    t.integer "category", default: 0, null: false
    t.jsonb "client_credential_fields", default: [], null: false
    t.datetime "created_at", null: false
    t.text "description_ar"
    t.text "description_en"
    t.string "documentation_url"
    t.string "integration_key", null: false
    t.integer "integration_type", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.boolean "is_featured", default: false, null: false
    t.string "logo"
    t.string "logo_dark"
    t.jsonb "merchant_credential_fields", default: [], null: false
    t.string "name_ar", null: false
    t.string "name_en", null: false
    t.string "oauth_authorize_url"
    t.jsonb "oauth_scopes", default: []
    t.string "oauth_token_url"
    t.float "priority", default: 0.0
    t.string "test_endpoint"
    t.string "test_method", default: "GET"
    t.datetime "updated_at", null: false
    t.string "version"
    t.jsonb "webhook_events", default: []
    t.index ["category"], name: "index_integrations_on_category"
    t.index ["client_credential_fields"], name: "index_integrations_on_client_credential_fields", using: :gin
    t.index ["integration_key"], name: "index_integrations_on_integration_key", unique: true
    t.index ["integration_type"], name: "index_integrations_on_integration_type"
    t.index ["is_active", "priority"], name: "index_integrations_on_is_active_and_priority"
    t.index ["logo"], name: "index_integrations_on_logo"
    t.index ["logo_dark"], name: "index_integrations_on_logo_dark"
    t.index ["merchant_credential_fields"], name: "index_integrations_on_merchant_credential_fields", using: :gin
  end

  create_table "inventories", force: :cascade do |t|
    t.string "color"
    t.integer "condition", default: 0
    t.datetime "created_at", null: false
    t.boolean "expirable", default: false
    t.date "expire_on"
    t.string "lot_number"
    t.integer "manifest_id"
    t.integer "merchant_id"
    t.integer "packaging_type"
    t.integer "product_id"
    t.float "purchase_price", default: 0.0
    t.float "quantity", default: 0.0
    t.float "reorder_level", default: 0.0
    t.float "safety_stock_level", default: 0.0
    t.float "selling_price", default: 0.0
    t.integer "sku_id"
    t.integer "status", default: 0
    t.integer "supplier_id"
    t.datetime "updated_at", null: false
  end

  create_table "inventory_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employee_id"
    t.integer "inventory_id"
    t.integer "manifest_id"
    t.integer "position_id"
    t.float "quantity"
    t.integer "transaction_type"
    t.datetime "updated_at", null: false
  end

  create_table "invoiced_tasks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.bigint "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoiced_tasks_on_invoice_id"
    t.index ["task_id"], name: "index_invoiced_tasks_on_task_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "account_id"
    t.text "additional_notes"
    t.jsonb "billing_from"
    t.jsonb "billing_to"
    t.float "cash_handling_total", default: 0.0
    t.datetime "created_at", null: false
    t.integer "currency", default: 0
    t.text "description"
    t.decimal "discounts", precision: 15, scale: 2
    t.datetime "due_date"
    t.string "invoice_number"
    t.integer "invoice_type"
    t.datetime "issue_date"
    t.integer "merchant_id"
    t.datetime "paid_at"
    t.text "payment_terms"
    t.text "simplified_invoice_qr"
    t.integer "status", default: 0
    t.string "stripe_invoice_id"
    t.text "stripe_invoice_url"
    t.string "stripe_payment_intent_id"
    t.decimal "subtotal", precision: 15, scale: 2
    t.decimal "taxes", precision: 15, scale: 2
    t.decimal "total", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_invoices_on_account_id_and_status"
    t.index ["stripe_invoice_id"], name: "index_invoices_on_stripe_invoice_id", unique: true
  end

# Could not dump table "localities" because of following StandardError
#   Unknown type 'geography' for column 'boundary'


  create_table "localities_zones", id: false, force: :cascade do |t|
    t.bigint "locality_id", null: false
    t.bigint "zone_id", null: false
    t.index ["locality_id", "zone_id"], name: "idx_localities_zones_locality_zone"
    t.index ["locality_id", "zone_id"], name: "index_localities_zones_on_locality_id_and_zone_id"
    t.index ["locality_id"], name: "index_localities_zones_on_locality_id"
    t.index ["zone_id", "locality_id"], name: "idx_localities_zones_zone_locality"
    t.index ["zone_id", "locality_id"], name: "index_localities_zones_on_zone_id_and_locality_id", unique: true
    t.index ["zone_id"], name: "index_localities_zones_on_zone_id"
  end

  create_table "manifests", force: :cascade do |t|
    t.datetime "assign_at"
    t.datetime "complete_at"
    t.datetime "created_at", null: false
    t.integer "employee_id"
    t.string "identifier"
    t.integer "merchant_id"
    t.integer "position_id"
    t.integer "purchase_order_id"
    t.integer "status"
    t.integer "tag"
    t.datetime "updated_at", null: false
    t.integer "warehouse_id"
  end

  create_table "merchant_api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "last_used_ip"
    t.bigint "merchant_id", null: false
    t.string "name", null: false
    t.datetime "revoked_at"
    t.jsonb "scopes", default: [], null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_merchant_api_tokens_on_expires_at"
    t.index ["merchant_id", "name"], name: "index_merchant_api_tokens_on_merchant_id_and_name"
    t.index ["merchant_id", "revoked_at"], name: "index_merchant_api_tokens_on_merchant_active"
    t.index ["merchant_id"], name: "index_merchant_api_tokens_on_merchant_id"
    t.index ["revoked_at"], name: "index_merchant_api_tokens_on_revoked_at"
    t.index ["token_digest"], name: "index_merchant_api_tokens_on_token_digest", unique: true
  end

  create_table "merchant_integration_credentials", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "credentials", default: {}, null: false
    t.string "external_merchant_id"
    t.string "external_store_name"
    t.string "external_store_url"
    t.bigint "integration_id", null: false
    t.text "last_sync_error"
    t.string "last_sync_status"
    t.datetime "last_synced_at"
    t.text "last_test_error"
    t.string "last_test_status"
    t.datetime "last_tested_at"
    t.bigint "merchant_id", null: false
    t.jsonb "metadata", default: {}
    t.text "notes"
    t.string "oauth_state"
    t.integer "refresh_attempts", default: 0
    t.integer "status", default: 0, null: false
    t.datetime "token_expires_at"
    t.datetime "token_refreshed_at"
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "idx_on_account_id_status_2d16834269"
    t.index ["account_id"], name: "index_merchant_integration_credentials_on_account_id"
    t.index ["credentials"], name: "index_merchant_integration_credentials_on_credentials", using: :gin
    t.index ["external_merchant_id"], name: "index_merchant_integration_credentials_on_external_merchant_id"
    t.index ["integration_id"], name: "index_merchant_integration_credentials_on_integration_id"
    t.index ["merchant_id", "integration_id"], name: "idx_merchant_integration_unique", unique: true
    t.index ["merchant_id"], name: "index_merchant_integration_credentials_on_merchant_id"
    t.index ["oauth_state"], name: "index_merchant_integration_credentials_on_oauth_state", unique: true, where: "(oauth_state IS NOT NULL)"
    t.index ["token_expires_at"], name: "index_merchant_integration_credentials_on_token_expires_at"
  end

  create_table "merchant_integrations", force: :cascade do |t|
    t.string "auth_token"
    t.datetime "created_at", null: false
    t.integer "merchant_id"
    t.integer "platform"
    t.string "platform_identifier"
    t.string "platform_user_id"
    t.string "refresh_token"
    t.integer "status"
    t.string "store_name"
    t.string "token_expires"
    t.datetime "updated_at", null: false
  end

  create_table "merchants", force: :cascade do |t|
    t.integer "account_id"
    t.integer "app_installed"
    t.string "bank_city"
    t.string "bank_country"
    t.string "bank_name"
    t.string "billing_email"
    t.text "callback_url"
    t.string "cr_certificate"
    t.string "cr_number"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "hq_city"
    t.string "hq_country"
    t.string "hq_street"
    t.string "iban"
    t.string "magic_link_token"
    t.datetime "magic_link_token_sent_at"
    t.string "manager_email"
    t.string "manager_mobile"
    t.string "manager_name"
    t.string "official_company_name_ar"
    t.string "official_company_name_en"
    t.string "password_digest"
    t.string "prefix"
    t.integer "status"
    t.string "store_name"
    t.string "store_url"
    t.bigint "subscription_id"
    t.string "swift_code"
    t.string "theme_preference", default: "light", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "vat_certificate"
    t.string "vat_number"
    t.index ["account_id", "status"], name: "index_merchants_on_account_and_status"
    t.index ["account_id"], name: "index_merchants_on_account_id"
    t.index ["email", "cr_number", "account_id"], name: "index_merchants_on_email_and_cr_number_and_account_id", unique: true
    t.index ["magic_link_token"], name: "index_merchants_on_magic_link_token", unique: true
    t.index ["subscription_id"], name: "index_merchants_on_subscription_id"
    t.index ["theme_preference"], name: "index_merchants_on_theme_preference"
  end

  create_table "merchants_subscriptions", id: false, force: :cascade do |t|
    t.bigint "merchant_id"
    t.bigint "subscription_id"
    t.index ["merchant_id"], name: "index_merchants_subscriptions_on_merchant_id"
    t.index ["subscription_id"], name: "index_merchants_subscriptions_on_subscription_id"
  end

  create_table "message_templates", force: :cascade do |t|
    t.integer "account_id"
    t.datetime "created_at", null: false
    t.integer "language"
    t.text "message"
    t.integer "message_type"
    t.integer "trigger"
    t.datetime "updated_at", null: false
  end

  create_table "nationalities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "status"
    t.datetime "updated_at", null: false
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

  create_table "orders", force: :cascade do |t|
    t.datetime "assigned_at"
    t.datetime "created_at", null: false
    t.integer "employee_packed_id"
    t.integer "employee_picked_id"
    t.integer "employee_received_id"
    t.integer "employee_shipped_id"
    t.string "identifier"
    t.integer "inventory_id"
    t.integer "merchant_id"
    t.datetime "packed_at"
    t.datetime "picked_at"
    t.float "quantity"
    t.datetime "received_at"
    t.datetime "shipped_at"
    t.jsonb "shipping_details"
    t.string "tracking_no"
    t.datetime "updated_at", null: false
  end

  create_table "positions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "identifier"
    t.string "name"
    t.integer "number"
    t.integer "shelf_id"
    t.integer "sku_id"
    t.datetime "updated_at", null: false
  end

  create_table "price_tiers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "description_ar"
    t.integer "invoicing", default: 0
    t.boolean "is_active", default: true
    t.string "name"
    t.string "name_ar"
    t.float "price"
    t.integer "range_end"
    t.integer "range_start"
    t.string "subtitle"
    t.string "subtitle_ar"
    t.string "title"
    t.string "title_ar"
    t.datetime "updated_at", null: false
    t.float "weight"
  end

  create_table "pricing_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.jsonb "value", default: {}, null: false
    t.index ["key"], name: "index_pricing_configs_on_key", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "barcode"
    t.string "brand"
    t.integer "category_id"
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "dimensions_unit"
    t.float "height"
    t.float "length"
    t.integer "material", default: 0
    t.string "name"
    t.integer "package", default: 0
    t.integer "size", default: 0
    t.datetime "updated_at", null: false
    t.float "weight"
    t.integer "weight_unit"
    t.float "width"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "depot_id"
    t.date "expected_on"
    t.string "identifier"
    t.integer "manifest_id"
    t.integer "merchant_id"
    t.jsonb "skus", default: []
    t.integer "status"
    t.string "tracking_no"
    t.datetime "updated_at", null: false
  end

  create_table "radars", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "recipients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "mobile"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["mobile"], name: "index_recipients_on_mobile", unique: true
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

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "depot_id"
    t.string "name"
    t.integer "room_type"
    t.integer "storage_type"
    t.datetime "updated_at", null: false
  end

  create_table "serial_numbers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id"
    t.integer "position_id"
    t.string "serial_number"
    t.integer "sku_id"
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
  end

  create_table "settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.text "description_ar"
    t.boolean "is_active"
    t.string "key"
    t.string "name"
    t.string "name_ar"
    t.integer "role"
    t.integer "setting_type"
    t.bigint "settingable_id"
    t.string "settingable_type"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["settingable_type", "settingable_id"], name: "index_settings_on_settingable"
  end

  create_table "shelves", force: :cascade do |t|
    t.bigint "bay_id", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.string "identifier"
    t.integer "level"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["bay_id"], name: "index_shelves_on_bay_id"
  end

  create_table "shipping_companies", force: :cascade do |t|
    t.integer "account_id"
    t.integer "company"
    t.datetime "created_at", null: false
    t.jsonb "credentials"
    t.float "priority", default: 0.0
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
  end

# Could not dump table "short_codes" because of following StandardError
#   Unknown type 'geography' for column 'boundary'


  create_table "sku_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "employee_id"
    t.integer "order_id"
    t.integer "position_id"
    t.float "quantity", default: 0.0
    t.integer "sku_id"
    t.integer "transaction_type", default: 0
    t.integer "unit"
    t.datetime "updated_at", null: false
  end

  create_table "skus", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expiry_at"
    t.integer "merchant_id"
    t.integer "notify_at", default: 0
    t.integer "notify_level", default: 0
    t.integer "position_id"
    t.integer "product_id"
    t.float "reorder_level", default: 0.0
    t.float "safety_stock_level", default: 0.0
    t.string "sku_number"
    t.datetime "updated_at", null: false
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "spatial_ref_sys", primary_key: "srid", id: :integer, default: nil, force: :cascade do |t|
    t.string "auth_name", limit: 256
    t.integer "auth_srid"
    t.string "proj4text", limit: 2048
    t.string "srtext", limit: 2048
    t.check_constraint "srid > 0 AND srid <= 998999", name: "spatial_ref_sys_srid_check"
  end

  create_table "storage_backends", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "encrypted_config"
    t.boolean "is_default", default: false, null: false
    t.boolean "managed", default: false, null: false
    t.string "name", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["managed"], name: "index_storage_backends_on_managed"
    t.index ["name"], name: "index_storage_backends_on_name_managed", unique: true, where: "(managed = true)"
    t.index ["user_id", "name"], name: "index_storage_backends_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_storage_backends_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "account_id"
    t.integer "attempts_limit", default: 3
    t.integer "cancellation_limit", default: 0
    t.float "cash_handling_price", default: 0.0
    t.datetime "created_at", null: false
    t.float "discount_percentage", default: 0.0
    t.integer "has_attempts", default: 0
    t.integer "has_cancellation", default: 1
    t.integer "has_cash_on_delivery", default: 0
    t.integer "has_insurance", default: 0
    t.integer "has_returns", default: 0
    t.integer "has_same_day", default: 0
    t.boolean "invoice_pickup", default: false
    t.integer "limit_type", default: 2
    t.float "max_insurance_value", default: 0.0
    t.string "name"
    t.float "return_price"
    t.float "task_price"
    t.integer "tasks_limit", default: 0
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_subscriptions_on_account_id"
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

  create_table "task_actions", force: :cascade do |t|
    t.integer "action"
    t.integer "carrier_id"
    t.datetime "created_at", null: false
    t.float "latitude"
    t.float "longitude"
    t.integer "task_id"
    t.datetime "updated_at", null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "address_id"
    t.jsonb "alternative_contact"
    t.integer "branch_id"
    t.integer "bundle_id"
    t.integer "carrier_id"
    t.boolean "client_invoiced", default: false
    t.string "confirmation_otp"
    t.datetime "created_at", null: false
    t.integer "currency"
    t.jsonb "customs_declaration"
    t.jsonb "delivery_attempts"
    t.integer "depot_id"
    t.jsonb "destination"
    t.float "estimated_arrival_time"
    t.string "external_shipment_id"
    t.jsonb "forwarding_details"
    t.bigint "locality_id"
    t.integer "merchant_id"
    t.boolean "merchant_invoiced", default: false
    t.jsonb "origin"
    t.jsonb "parcel_details"
    t.integer "parcel_type"
    t.integer "payment_collection"
    t.jsonb "payment_details"
    t.jsonb "payment_metadata"
    t.integer "payment_method"
    t.float "priority"
    t.bigint "recipient_id"
    t.decimal "reward_amount", precision: 10, scale: 2
    t.datetime "reward_calculated_at"
    t.bigint "reward_transaction_id"
    t.jsonb "schedules"
    t.jsonb "sender_details"
    t.integer "source"
    t.string "source_ref"
    t.jsonb "sync_metadata", default: {}, null: false
    t.integer "task_status"
    t.integer "task_type"
    t.float "tax_amount"
    t.float "total_amount"
    t.string "tracking_no"
    t.integer "transit_type", default: 0
    t.datetime "updated_at", null: false
    t.index ["address_id"], name: "idx_tasks_address", where: "(address_id IS NOT NULL)"
    t.index ["address_id"], name: "index_tasks_on_address_id"
    t.index ["branch_id"], name: "index_tasks_on_branch_id"
    t.index ["bundle_id", "task_status"], name: "index_tasks_on_bundle_id_and_task_status"
    t.index ["bundle_id"], name: "index_tasks_on_bundle_id"
    t.index ["carrier_id", "task_status"], name: "index_tasks_on_carrier_id_and_task_status"
    t.index ["carrier_id"], name: "index_tasks_on_carrier_id"
    t.index ["created_at", "task_status"], name: "index_tasks_on_created_at_and_task_status"
    t.index ["created_at", "task_type"], name: "index_tasks_on_created_at_and_task_type"
    t.index ["depot_id", "task_status"], name: "index_tasks_on_depot_id_and_task_status"
    t.index ["depot_id"], name: "index_tasks_on_depot_id"
    t.index ["forwarding_details"], name: "index_tasks_on_forwarding_details_gin", using: :gin
    t.index ["locality_id"], name: "index_tasks_on_locality_id"
    t.index ["merchant_id", "created_at"], name: "index_tasks_on_merchant_id_and_created_at"
    t.index ["merchant_id", "task_status", "created_at"], name: "index_tasks_on_merchant_status_created"
    t.index ["merchant_id", "task_status"], name: "index_tasks_on_merchant_id_and_task_status"
    t.index ["payment_details"], name: "index_tasks_on_payment_details_gin", using: :gin
    t.index ["recipient_id"], name: "index_tasks_on_recipient_id"
    t.index ["reward_calculated_at"], name: "index_tasks_on_reward_calculated_at"
    t.index ["reward_transaction_id"], name: "index_tasks_on_reward_transaction_id"
    t.index ["schedules"], name: "index_tasks_on_schedules_gin", using: :gin
    t.index ["source", "external_shipment_id"], name: "index_tasks_on_source_and_external_shipment_id"
    t.index ["sync_metadata"], name: "index_tasks_on_sync_metadata", using: :gin
    t.index ["task_status", "merchant_id"], name: "idx_tasks_pending_by_merchant", where: "(task_status = ANY (ARRAY[1, 13, 11, 3]))"
  end

  create_table "ticket_replies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message", null: false
    t.bigint "replier_id", null: false
    t.string "replier_type", null: false
    t.bigint "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["replier_type", "replier_id"], name: "index_ticket_replies_on_replier"
    t.index ["ticket_id", "created_at"], name: "index_ticket_replies_on_ticket_id_and_created_at"
    t.index ["ticket_id"], name: "index_ticket_replies_on_ticket_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "category", default: 0, null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.integer "priority", default: 1, null: false
    t.datetime "resolution_date"
    t.bigint "resolved_by_id"
    t.integer "status", default: 0, null: false
    t.string "subject", null: false
    t.string "ticket_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "category"], name: "index_tickets_on_account_id_and_category"
    t.index ["account_id", "status"], name: "index_tickets_on_account_id_and_status"
    t.index ["account_id"], name: "index_tickets_on_account_id"
    t.index ["client_id", "status"], name: "index_tickets_on_client_id_and_status"
    t.index ["client_id"], name: "index_tickets_on_client_id"
    t.index ["resolved_by_id"], name: "index_tickets_on_resolved_by_id"
    t.index ["ticket_id"], name: "index_tickets_on_ticket_id", unique: true
  end

  create_table "timelines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.text "message"
    t.integer "status"
    t.bigint "timelineable_id", null: false
    t.string "timelineable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["timelineable_id", "timelineable_type", "status"], name: "index_timelines_on_timelineable_and_status"
    t.index ["timelineable_type", "timelineable_id", "status"], name: "index_timelines_on_unique_status_per_record", unique: true, where: "(status IS NOT NULL)"
    t.index ["timelineable_type", "timelineable_id"], name: "index_timelines_on_timelineable"
  end

  create_table "training_modules", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "category"
    t.string "code"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_minutes"
    t.boolean "is_mandatory"
    t.string "name"
    t.integer "passing_score"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_training_modules_on_account_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.float "amount", default: 0.0, null: false
    t.float "closing_balance", null: false
    t.datetime "created_at", null: false
    t.string "description", null: false
    t.integer "issued_by", null: false
    t.integer "issuer_id"
    t.float "opening_balance", null: false
    t.string "reference"
    t.integer "transaction_type"
    t.datetime "updated_at", null: false
    t.bigint "wallet_id", null: false
    t.index ["wallet_id"], name: "index_transactions_on_wallet_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.string "provider"
    t.integer "role", default: 0, null: false
    t.string "stripe_customer_id"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
    t.index ["role"], name: "index_users_on_role"
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  create_table "vehicle_fuel_logs", force: :cascade do |t|
    t.decimal "cost", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "fuel_date", null: false
    t.string "fuel_station"
    t.integer "fuel_type", default: 0
    t.text "notes"
    t.integer "odometer_reading", null: false
    t.decimal "quantity_liters", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["vehicle_id", "fuel_date"], name: "idx_fuel_logs_vehicle_date"
    t.index ["vehicle_id", "odometer_reading"], name: "idx_fuel_logs_vehicle_odometer"
    t.index ["vehicle_id"], name: "index_vehicle_fuel_logs_on_vehicle_id"
  end

  create_table "vehicle_insurance_policies", force: :cascade do |t|
    t.text "coverage_details"
    t.datetime "created_at", null: false
    t.decimal "deductible", precision: 10, scale: 2
    t.date "end_date", null: false
    t.integer "insurance_type", default: 0
    t.text "notes"
    t.string "policy_number", null: false
    t.decimal "premium", precision: 10, scale: 2, null: false
    t.string "provider", null: false
    t.date "start_date", null: false
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["end_date"], name: "idx_insurance_expiry_alerts"
    t.index ["vehicle_id", "end_date"], name: "idx_insurance_vehicle_expiry"
    t.index ["vehicle_id", "status"], name: "idx_insurance_vehicle_status"
    t.index ["vehicle_id"], name: "index_vehicle_insurance_policies_on_vehicle_id"
  end

  create_table "vehicle_maintenance_logs", force: :cascade do |t|
    t.datetime "completed_at"
    t.decimal "cost", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.text "description"
    t.string "maintenance_type", null: false
    t.datetime "next_maintenance_due"
    t.integer "odometer_reading"
    t.string "parts_replaced"
    t.datetime "performed_at", null: false
    t.string "performed_by"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["next_maintenance_due"], name: "idx_vmaint_logs_on_next_due"
    t.index ["vehicle_id", "maintenance_type"], name: "idx_vmaint_logs_on_vehicle_and_type"
    t.index ["vehicle_id"], name: "index_vehicle_maintenance_logs_on_vehicle_id"
  end

  create_table "vehicle_mileage_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "log_date", null: false
    t.bigint "loggable_id"
    t.string "loggable_type"
    t.text "notes"
    t.integer "odometer_reading", null: false
    t.integer "source", default: 0
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["loggable_type", "loggable_id"], name: "index_vehicle_mileage_logs_on_loggable"
    t.index ["vehicle_id", "log_date"], name: "idx_mileage_logs_vehicle_date"
    t.index ["vehicle_id", "odometer_reading"], name: "idx_mileage_logs_vehicle_odometer", unique: true
    t.index ["vehicle_id"], name: "index_vehicle_mileage_logs_on_vehicle_id"
  end

  create_table "vehicle_registration_licenses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "expiry_date", null: false
    t.date "issue_date"
    t.string "license_number", null: false
    t.text "notes"
    t.decimal "renewal_cost", precision: 10, scale: 2
    t.integer "status", default: 0
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["vehicle_id", "expiry_date"], name: "idx_on_vehicle_id_expiry_date_c55c5674e6"
    t.index ["vehicle_id"], name: "index_vehicle_registration_licenses_on_vehicle_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "current_odometer", default: 0
    t.string "engine_size"
    t.bigint "fleet_id"
    t.integer "fuel_type_vehicle", default: 0
    t.datetime "last_maintenance_at"
    t.string "make"
    t.string "model"
    t.datetime "next_maintenance_at"
    t.string "plate_number"
    t.date "purchase_date"
    t.decimal "purchase_price", precision: 12, scale: 2
    t.integer "status", default: 0
    t.decimal "tank_capacity_liters", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.integer "vehicle_type", default: 0
    t.string "vin_number"
    t.integer "year"
    t.index ["current_odometer"], name: "index_vehicles_on_current_odometer"
    t.index ["fleet_id", "status"], name: "index_vehicles_on_fleet_id_and_status"
    t.index ["fleet_id"], name: "index_vehicles_on_fleet_id"
    t.index ["plate_number"], name: "index_vehicles_on_plate_number", unique: true
    t.index ["vin_number"], name: "index_vehicles_on_vin_number", unique: true, where: "(vin_number IS NOT NULL)"
  end

  create_table "wallets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "walletable_id"
    t.string "walletable_type"
    t.index ["walletable_type", "walletable_id"], name: "index_wallets_on_walletable"
  end

  create_table "zones", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.integer "compass"
    t.datetime "created_at", null: false
    t.string "name_ar"
    t.string "name_en"
    t.string "name_es"
    t.string "name_fr"
    t.string "name_ru"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_zones_on_account_id"
  end

  add_foreign_key "account_domains", "accounts"
  add_foreign_key "account_integration_credentials", "accounts"
  add_foreign_key "account_integration_credentials", "integrations"
  add_foreign_key "account_integrations", "accounts"
  add_foreign_key "account_status_changes", "accounts"
  add_foreign_key "account_status_changes", "admins"
  add_foreign_key "accounts", "admins", column: "approved_by_id", on_delete: :nullify
  add_foreign_key "accounts", "countries", validate: false
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "aisles", "rooms"
  add_foreign_key "android_app_versions", "android_apps"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "backup_job_notification_channels", "backup_jobs"
  add_foreign_key "backup_job_notification_channels", "notification_channels"
  add_foreign_key "backup_job_storage_backends", "backup_jobs"
  add_foreign_key "backup_job_storage_backends", "storage_backends"
  add_foreign_key "backup_jobs", "database_configs"
  add_foreign_key "backup_jobs", "storage_backends"
  add_foreign_key "backup_jobs", "users"
  add_foreign_key "backups", "backup_jobs"
  add_foreign_key "backups", "storage_backends"
  add_foreign_key "bays", "aisles"
  add_foreign_key "carrier_certifications", "accounts"
  add_foreign_key "carrier_certifications", "carriers"
  add_foreign_key "carrier_certifications", "certifications"
  add_foreign_key "carrier_documents", "accounts"
  add_foreign_key "carrier_documents", "carriers"
  add_foreign_key "carrier_locations", "carriers"
  add_foreign_key "carrier_reward_schemes", "accounts", on_delete: :cascade
  add_foreign_key "carrier_trainings", "accounts"
  add_foreign_key "carrier_trainings", "carriers"
  add_foreign_key "carrier_trainings", "training_modules"
  add_foreign_key "certifications", "accounts"
  add_foreign_key "cities", "countries"
  add_foreign_key "city_shipping_companies", "cities"
  add_foreign_key "city_shipping_companies", "shipping_companies"
  add_foreign_key "client_login_events", "accounts"
  add_foreign_key "client_login_events", "clients"
  add_foreign_key "client_request_logs", "accounts"
  add_foreign_key "database_configs", "enterprise_quotes"
  add_foreign_key "database_configs", "users"
  add_foreign_key "devices", "carriers"
  add_foreign_key "distance_tiers", "carrier_reward_schemes"
  add_foreign_key "enterprise_quotes", "users"
  add_foreign_key "enterprise_quotes", "users", column: "admin_user_id"
  add_foreign_key "fleet_assignments", "bundles"
  add_foreign_key "fleet_assignments", "fleets"
  add_foreign_key "fleet_assignments", "vehicles"
  add_foreign_key "fleet_merchants", "fleets"
  add_foreign_key "fleet_merchants", "merchants"
  add_foreign_key "forwarding_rules", "account_integrations"
  add_foreign_key "forwarding_rules", "accounts"
  add_foreign_key "forwarding_rules", "cities", column: "destination_city_id"
  add_foreign_key "forwarding_rules", "cities", column: "origin_city_id"
  add_foreign_key "forwarding_rules", "merchants"
  add_foreign_key "health_checks", "database_configs"
  add_foreign_key "invoiced_tasks", "invoices"
  add_foreign_key "invoiced_tasks", "tasks"
  add_foreign_key "merchant_api_tokens", "merchants"
  add_foreign_key "merchant_integration_credentials", "accounts"
  add_foreign_key "merchant_integration_credentials", "integrations"
  add_foreign_key "merchant_integration_credentials", "merchants"
  add_foreign_key "merchants", "subscriptions"
  add_foreign_key "notification_channels", "users"
  add_foreign_key "restores", "backups"
  add_foreign_key "restores", "database_configs"
  add_foreign_key "restores", "users"
  add_foreign_key "shelves", "bays"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "storage_backends", "users"
  add_foreign_key "sync_executions", "sync_jobs"
  add_foreign_key "sync_job_targets", "database_configs"
  add_foreign_key "sync_job_targets", "sync_jobs"
  add_foreign_key "sync_jobs", "database_configs", column: "source_database_config_id"
  add_foreign_key "sync_jobs", "users"
  add_foreign_key "tasks", "addresses"
  add_foreign_key "tasks", "localities"
  add_foreign_key "tasks", "recipients"
  add_foreign_key "tasks", "transactions", column: "reward_transaction_id", on_delete: :nullify
  add_foreign_key "ticket_replies", "tickets"
  add_foreign_key "tickets", "accounts"
  add_foreign_key "tickets", "admins", column: "resolved_by_id"
  add_foreign_key "tickets", "clients"
  add_foreign_key "training_modules", "accounts"
  add_foreign_key "transactions", "wallets"
  add_foreign_key "vehicle_fuel_logs", "vehicles"
  add_foreign_key "vehicle_insurance_policies", "vehicles"
  add_foreign_key "vehicle_maintenance_logs", "vehicles"
  add_foreign_key "vehicle_mileage_logs", "vehicles"
  add_foreign_key "vehicle_registration_licenses", "vehicles"
  add_foreign_key "vehicles", "fleets"
  add_foreign_key "zones", "accounts"
end
