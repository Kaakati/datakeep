# frozen_string_literal: true

class BillingController < ApplicationController
  def show
    @plan_limits = current_user.plan_limits
    @usage = current_user.resource_usage
    @quote = current_user.active_enterprise_quote
    @subscription = current_user.subscription
    @current_tier = current_user.plan_tier_key
    @tier_definitions = PlanTierLimits::TIER_DEFINITIONS

    # DB-backed plans for the pricing grid (enabled only)
    @db_plans = SubscriptionPlan.enabled_paid_tiers

    # Computed billing page variables
    @next_tier = next_tier_for(@current_tier)
    @hit_limits = hit_limits(@usage, @plan_limits)
    @usage_health = compute_usage_health(@usage, @plan_limits)
    @next_tier_definition = @next_tier ? tier_definition_for(@next_tier) : nil
  end

  private

  TIER_UPGRADE_PATH = {
    free: :starter,
    starter: :professional,
    professional: :business,
    business: nil,
    enterprise: nil
  }.freeze

  USAGE_TO_LIMIT_MAP = {
    database_configs: :max_database_configs,
    backup_jobs: :max_backup_jobs,
    sync_jobs: :max_sync_jobs,
    restores_this_month: :max_restores_per_month,
    storage_used_gb: :default_size_gb
  }.freeze

  USAGE_LABELS = {
    database_configs: "Databases",
    backup_jobs: "Backup Jobs",
    sync_jobs: "Sync Jobs",
    restores_this_month: "Restores",
    storage_used_gb: "Storage"
  }.freeze

  def next_tier_for(current)
    TIER_UPGRADE_PATH[current&.to_sym]
  end

  def hit_limits(usage, limits)
    hit = []

    USAGE_TO_LIMIT_MAP.each do |usage_key, limit_key|
      used = usage[usage_key].to_i
      limit = limits[limit_key]

      next if limit.nil?

      if limit == 0 || (limit > 0 && used >= limit)
        hit << USAGE_LABELS[usage_key]
      end
    end

    # Check S3 access
    if limits[:s3_allowed] == false || limits[:s3_allowed] == 0
      hit << "Cloud Storage"
    end

    hit
  end

  def compute_usage_health(usage, limits)
    health = {}

    USAGE_TO_LIMIT_MAP.each do |usage_key, limit_key|
      used = usage[usage_key].to_i
      limit = limits[limit_key]

      health[usage_key] = if limit.nil?
                            :unlimited
                          elsif limit == 0 || (limit > 0 && used >= limit)
                            :critical
                          elsif limit > 0 && used.to_f / limit >= 0.7
                            :warning
                          else
                            :healthy
                          end
    end

    health
  end

  def tier_definition_for(key)
    db_plan = @db_plans.find { |p| p.tier_key == key.to_s }
    return db_plan.merged_limits if db_plan&.respond_to?(:merged_limits)

    @tier_definitions[key.to_sym]
  end
end
