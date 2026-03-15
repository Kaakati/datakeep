# frozen_string_literal: true

module DataKeep
  module Stripe
    class SubscriptionService
      def self.create_from_quote(enterprise_quote:)
        new(enterprise_quote).create
      end

      def initialize(enterprise_quote)
        @quote = enterprise_quote
      end

      def create
        user = @quote.user
        customer_id = user.stripe_customer_id

        raise "Cannot create subscription: user #{user.id} (#{user.email}) has no stripe_customer_id" unless customer_id

        # Idempotency: don't create duplicate if subscription already exists for this quote
        return @quote.subscription.stripe_subscription_id if @quote.subscription.present?

        # Create custom Stripe Product per enterprise customer
        product = ::Stripe::Product.create(
          name: "DataKeep Enterprise — #{user.name}",
          metadata: {
            enterprise_quote_id: @quote.id,
            datakeep_user_id: user.id
          }
        )

        # Create price from quote amount
        price = ::Stripe::Price.create(
          product: product.id,
          unit_amount: @quote.total_monthly_cents,
          currency: @quote.currency,
          recurring: { interval: "month" }
        )

        # Create Stripe subscription
        sub_params = {
          customer: customer_id,
          items: [ { price: price.id } ],
          metadata: {
            enterprise_quote_id: @quote.id,
            datakeep_user_id: user.id
          }
        }

        sub_params[:coupon] = @quote.stripe_coupon_id if @quote.stripe_coupon_id.present?

        stripe_sub = ::Stripe::Subscription.create(sub_params)

        # Store stripe_product_id on the quote
        @quote.update!(
          stripe_subscription_id: stripe_sub.id,
          stripe_product_id: product.id
        )

        # Destroy any pre-existing local subscription (upgrade from self-service)
        user.subscription&.destroy

        # Create local Subscription record
        user.create_subscription!(
          plan_tier: :enterprise,
          billing_interval: :monthly,
          status: :active,
          stripe_subscription_id: stripe_sub.id,
          stripe_price_id: price.id,
          current_period_end_epoch: stripe_sub.current_period_end,
          enterprise_quote_id: @quote.id
        )

        stripe_sub.id
      end
    end
  end
end
