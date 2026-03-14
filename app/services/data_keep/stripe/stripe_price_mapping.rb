# frozen_string_literal: true

module DataKeep
  module Stripe
    class StripePriceMapping
      # Fallback env var keys when DB plans are not configured
      PRICE_ENV_KEYS = {
        starter: { monthly: "STRIPE_PRICE_STARTER_MONTHLY", annual: "STRIPE_PRICE_STARTER_ANNUAL" },
        professional: { monthly: "STRIPE_PRICE_PROFESSIONAL_MONTHLY", annual: "STRIPE_PRICE_PROFESSIONAL_ANNUAL" },
        business: { monthly: "STRIPE_PRICE_BUSINESS_MONTHLY", annual: "STRIPE_PRICE_BUSINESS_ANNUAL" }
      }.freeze

      def self.price_id_for(plan_tier:, billing_interval:)
        tier_key = plan_tier.to_sym
        interval_key = billing_interval.to_sym

        # Try DB-backed plan first
        db_plan = SubscriptionPlan.for_tier(tier_key)
        if db_plan
          price_id = db_plan.price_id_for(interval_key)
          return price_id if price_id.present?
        end

        # Fall back to env vars
        env_key = PRICE_ENV_KEYS.dig(tier_key, interval_key)
        raise ArgumentError, "No price mapping for #{plan_tier}/#{billing_interval}" unless env_key

        price_id = ENV[env_key]
        raise "Missing Stripe price for #{plan_tier}/#{billing_interval}. " \
              "Sync the plan to Stripe via Admin > Subscription Plans, or set #{env_key}." if price_id.blank?

        price_id
      end

      def self.tier_from_price_id(price_id)
        # Try DB-backed plans first
        SubscriptionPlan.find_each do |plan|
          return { plan_tier: plan.tier_key.to_sym, billing_interval: :monthly } if plan.stripe_monthly_price_id == price_id
          return { plan_tier: plan.tier_key.to_sym, billing_interval: :annual } if plan.stripe_annual_price_id == price_id
        end

        # Fall back to env vars
        PRICE_ENV_KEYS.each do |tier, intervals|
          intervals.each do |interval, env_key|
            return { plan_tier: tier, billing_interval: interval } if ENV[env_key] == price_id
          end
        end

        nil
      end
    end
  end
end
