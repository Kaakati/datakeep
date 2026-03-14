# frozen_string_literal: true

module DataKeep
  module Stripe
    class CancelSubscriptionService
      def initialize(user:)
        @user = user
        @subscription = user.subscription
      end

      def call
        return { error: "No active subscription" } unless @subscription&.active?

        ::Stripe::Subscription.update(
          @subscription.stripe_subscription_id,
          cancel_at_period_end: true
        )

        @subscription.update!(
          cancel_at_period_end: true,
          canceled_at: Time.current
        )

        { success: true }
      rescue ::Stripe::StripeError => e
        { error: e.message }
      end
    end
  end
end
