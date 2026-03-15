# frozen_string_literal: true

module DataKeep
  module Stripe
    class CheckoutService
      class CouponError < StandardError; end

      def initialize(user:, plan_tier:, billing_interval:, coupon_code: nil)
        @user = user
        @plan_tier = plan_tier
        @billing_interval = billing_interval
        @coupon_code = coupon_code
      end

      def call
        customer_id = CustomerService.find_or_create(user: @user)
        price_id = StripePriceMapping.price_id_for(
          plan_tier: @plan_tier,
          billing_interval: @billing_interval
        )

        session_params = {
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
        }

        apply_coupon!(session_params) if @coupon_code.present?

        session = ::Stripe::Checkout::Session.create(session_params)

        session.url
      end

      private

      def apply_coupon!(session_params)
        coupon = Coupon.find_by(code: @coupon_code)
        raise CouponError, "Invalid or expired coupon code." unless coupon&.valid_for_checkout?(@plan_tier)

        session_params[:discounts] = [{ coupon: coupon.stripe_coupon_id }]
        coupon.record_redemption!
      end

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
