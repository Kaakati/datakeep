# frozen_string_literal: true

module DataKeep
  module Stripe
    class SubscriptionService
      PRODUCT_NAME = "DataKeep Enterprise"

      def self.create_from_quote(enterprise_quote:)
        new(enterprise_quote).create
      end

      def initialize(enterprise_quote)
        @quote = enterprise_quote
      end

      def create
        customer_id = @quote.user.stripe_customer_id
        return unless customer_id

        # Find or create product
        products = ::Stripe::Product.list(limit: 1)
        product = products.data.find { |p| p.name == PRODUCT_NAME }
        product ||= ::Stripe::Product.create(name: PRODUCT_NAME)

        # Create price for this quote's amount
        price = ::Stripe::Price.create(
          product: product.id,
          unit_amount: @quote.total_monthly_cents,
          currency: @quote.currency,
          recurring: { interval: "month" }
        )

        # Create subscription
        sub_params = {
          customer: customer_id,
          items: [ { price: price.id } ],
          metadata: { enterprise_quote_id: @quote.id }
        }

        if @quote.stripe_coupon_id.present?
          sub_params[:coupon] = @quote.stripe_coupon_id
        end

        subscription = ::Stripe::Subscription.create(sub_params)

        @quote.update!(stripe_subscription_id: subscription.id)
        subscription.id
      end
    end
  end
end
