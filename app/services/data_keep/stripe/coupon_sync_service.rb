# frozen_string_literal: true

module DataKeep
  module Stripe
    class CouponSyncService
      def initialize(coupon)
        @coupon = coupon
      end

      def call
        stripe_params = build_stripe_params
        stripe_coupon = create_stripe_coupon(stripe_params)

        @coupon.update!(stripe_coupon_id: stripe_coupon.id)

        { success: true, stripe_coupon_id: stripe_coupon.id }
      rescue ::Stripe::InvalidRequestError => e
        if e.message.include?("already exists") && !@retried
          @retried = true
          stripe_params[:id] = "#{stripe_params[:id]}-#{Time.current.to_i}"
          retry
        end
        { success: false, error: e.message }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      private

      def build_stripe_params
        params = {
          id: @coupon.code.downcase,
          name: @coupon.code,
          duration: @coupon.duration
        }

        if @coupon.percent_off?
          params[:percent_off] = @coupon.discount_value
        else
          params[:amount_off] = @coupon.discount_value
          params[:currency] = @coupon.currency
        end

        params[:duration_in_months] = @coupon.duration_in_months if @coupon.repeating?
        params[:max_redemptions] = @coupon.max_redemptions if @coupon.max_redemptions.present?
        params[:redeem_by] = @coupon.expires_at.to_i if @coupon.expires_at.present?

        params
      end

      def create_stripe_coupon(params)
        ::Stripe::Coupon.create(params)
      end
    end
  end
end
