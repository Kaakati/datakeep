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
  end
end
