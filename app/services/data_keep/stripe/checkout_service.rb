# frozen_string_literal: true

module DataKeep
  module Stripe
    class CheckoutService
      def initialize(user:, plan_tier:, billing_interval:)
        @user = user
        @plan_tier = plan_tier
        @billing_interval = billing_interval
      end

      def call
        customer_id = CustomerService.find_or_create(user: @user)
        price_id = StripePriceMapping.price_id_for(
          plan_tier: @plan_tier,
          billing_interval: @billing_interval
        )

        session = ::Stripe::Checkout::Session.create(
          customer: customer_id,
          mode: "subscription",
          line_items: [{ price: price_id, quantity: 1 }],
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: {
            datakeep_user_id: @user.id,
            plan_tier: @plan_tier,
            billing_interval: @billing_interval
          },
          subscription_data: {
            metadata: {
              datakeep_user_id: @user.id,
              plan_tier: @plan_tier,
              billing_interval: @billing_interval
            }
          }
        )

        session.url
      end

      private

      def base_url
        ENV.fetch("APP_BASE_URL", "http://localhost:3000")
      end

      def success_url
        "#{base_url}/billing?checkout=success&session_id={CHECKOUT_SESSION_ID}"
      end

      def cancel_url
        "#{base_url}/billing?checkout=canceled"
      end
    end
  end
end
