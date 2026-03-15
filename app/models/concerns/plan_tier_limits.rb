# frozen_string_literal: true

module PlanTierLimits
  extend ActiveSupport::Concern

  TIER_DEFINITIONS = {
    free: {
      label: "Free",
      max_database_configs: 1,
      max_backup_jobs: 1,
      max_storage_backends: 2,
      max_notification_channels: 0,
      max_retention_days: 7,
      max_storage_gb: 2,
      max_zones: 1,
      max_jobs_per_month: 31,
      min_backup_interval: "daily",
      min_backup_interval_minutes: 1440,
      max_sync_jobs: 0,
      min_sync_interval_minutes: nil,
      max_restores_per_month: 2,
      s3_allowed: false,
      monthly_price_cents: 0,
      annual_price_cents: 0
    },
    starter: {
      label: "Starter",
      max_database_configs: 3,
      max_backup_jobs: nil,
      max_storage_backends: nil,
      max_notification_channels: 3,
      max_retention_days: 14,
      max_storage_gb: 10,
      max_zones: 1,
      max_jobs_per_month: 5_000,
      min_backup_interval: "daily",
      min_backup_interval_minutes: 1440,
      max_sync_jobs: 2,
      min_sync_interval_minutes: 60,
      max_restores_per_month: 20,
      s3_allowed: true,
      monthly_price_cents: 3_900,
      annual_price_cents: 37_440
    },
    professional: {
      label: "Professional",
      max_database_configs: 10,
      max_backup_jobs: nil,
      max_storage_backends: nil,
      max_notification_channels: 10,
      max_retention_days: 60,
      max_storage_gb: 50,
      max_zones: 2,
      max_jobs_per_month: 50_000,
      min_backup_interval: "hourly",
      min_backup_interval_minutes: 60,
      max_sync_jobs: 10,
      min_sync_interval_minutes: 15,
      max_restores_per_month: 100,
      s3_allowed: true,
      monthly_price_cents: 9_900,
      annual_price_cents: 95_040
    },
    business: {
      label: "Business",
      max_database_configs: 30,
      max_backup_jobs: nil,
      max_storage_backends: nil,
      max_notification_channels: nil,
      max_retention_days: 365,
      max_storage_gb: 200,
      max_zones: 3,
      max_jobs_per_month: 500_000,
      min_backup_interval: "every_15_min",
      min_backup_interval_minutes: 15,
      max_sync_jobs: nil,
      min_sync_interval_minutes: 5,
      max_restores_per_month: nil,
      s3_allowed: true,
      monthly_price_cents: 29_900,
      annual_price_cents: 287_040
    }
  }.freeze
end
