# frozen_string_literal: true

module DataKeep
  module Stripe
    class PlanSyncService
      PRODUCT_NAME = "DataKeep"

      def initialize(subscription_plan)
        @plan = subscription_plan
      end

      def call
        product = find_or_create_product
        monthly_price = create_or_find_price(product, :monthly)
        annual_price = create_or_find_price(product, :annual)

        @plan.update!(
          stripe_product_id: product.id,
          stripe_monthly_price_id: monthly_price.id,
          stripe_annual_price_id: annual_price.id
        )

        { success: true, product_id: product.id }
      rescue ::Stripe::StripeError => e
        { success: false, error: e.message }
      end

      private

      def find_or_create_product
        if @plan.stripe_product_id.present?
          begin
            product = ::Stripe::Product.retrieve(@plan.stripe_product_id)
            ::Stripe::Product.update(product.id, name: "#{PRODUCT_NAME} — #{@plan.name}")
            return product
          rescue ::Stripe::InvalidRequestError
            # Product was deleted in Stripe, create a new one
          end
        end

        ::Stripe::Product.create(
          name: "#{PRODUCT_NAME} — #{@plan.name}",
          metadata: { tier_key: @plan.tier_key, datakeep_plan_id: @plan.id }
        )
      end

      def create_or_find_price(product, interval)
        amount = interval == :monthly ? @plan.monthly_price_cents : @plan.annual_price_cents
        stripe_interval = interval == :monthly ? "month" : "year"
        existing_price_id = @plan.price_id_for(interval)

        # If we have an existing price, check if amount matches
        if existing_price_id.present?
          begin
            existing = ::Stripe::Price.retrieve(existing_price_id)
            return existing if existing.unit_amount == amount && existing.active
          rescue ::Stripe::InvalidRequestError
            # Price deleted, create new one
          end
        end

        # Prices are immutable in Stripe — archive old, create new
        if existing_price_id.present?
          begin
            ::Stripe::Price.update(existing_price_id, active: false)
          rescue ::Stripe::InvalidRequestError
            # Already archived or deleted
          end
        end

        ::Stripe::Price.create(
          product: product.id,
          unit_amount: amount,
          currency: "usd",
          recurring: { interval: stripe_interval },
          lookup_key: "datakeep_#{@plan.tier_key}_#{interval}",
          transfer_lookup_key: true,
          metadata: { tier_key: @plan.tier_key, interval: interval.to_s, datakeep_plan_id: @plan.id }
        )
      end
    end
  end
end
