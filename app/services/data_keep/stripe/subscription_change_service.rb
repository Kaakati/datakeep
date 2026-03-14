# frozen_string_literal: true

module DataKeep
  module Stripe
    class SubscriptionChangeService
      def initialize(user:, new_plan_tier:, new_billing_interval: nil)
        @user = user
        @subscription = user.subscription
        @new_plan_tier = new_plan_tier.to_s
        @new_billing_interval = (new_billing_interval || @subscription.billing_interval).to_s
      end

      def call
        return { error: "No active subscription" } unless @subscription&.active_access?

        new_price_id = StripePriceMapping.price_id_for(
          plan_tier: @new_plan_tier,
          billing_interval: @new_billing_interval
        )

        stripe_sub = ::Stripe::Subscription.retrieve(@subscription.stripe_subscription_id)
        current_item = stripe_sub.items.data.first

        if upgrade?
          ::Stripe::Subscription.update(
            @subscription.stripe_subscription_id,
            items: [{ id: current_item.id, price: new_price_id }],
            proration_behavior: "always_invoice"
          )
        else
          ::Stripe::Subscription.update(
            @subscription.stripe_subscription_id,
            items: [{ id: current_item.id, price: new_price_id }],
            proration_behavior: "none",
            billing_cycle_anchor: "unchanged"
          )
        end

        @subscription.update!(
          plan_tier: @new_plan_tier,
          billing_interval: @new_billing_interval,
          stripe_price_id: new_price_id
        )

        { success: true }
      rescue ::Stripe::StripeError => e
        { error: e.message }
      end

      private

      def upgrade?
        new_tier_value = Subscription.plan_tiers[@new_plan_tier]
        current_tier_value = Subscription.plan_tiers[@subscription.plan_tier]
        new_tier_value > current_tier_value
      end
    end
  end
end
