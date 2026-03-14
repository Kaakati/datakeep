# frozen_string_literal: true

module DataKeep
  module Stripe
    class WebhookHandler
      def initialize(event)
        @event = event
      end

      def process
        case @event.type
        when "invoice.paid"
          handle_invoice_paid
        when "invoice.payment_failed"
          handle_payment_failed
        when "customer.subscription.deleted"
          handle_subscription_deleted
        when "checkout.session.completed"
          handle_checkout_completed
        when "customer.subscription.updated"
          handle_subscription_updated
        else
          Rails.logger.info("Unhandled Stripe event: #{@event.type}")
        end
      end

      private

      # --- Enterprise handlers (existing) ---

      def handle_invoice_paid
        invoice = @event.data.object
        quote = EnterpriseQuote.find_by(stripe_invoice_id: invoice.id)
        return unless quote
        return if quote.paid?

        quote.update!(status: :paid, paid_at: Time.current)
        SubscriptionService.create_from_quote(enterprise_quote: quote)

        quote.admin_user.log_action(
          "enterprise_quote_paid",
          resource: quote,
          details: { invoice_id: invoice.id, user_email: quote.user.email }
        )
      end

      def handle_payment_failed
        invoice = @event.data.object
        quote = EnterpriseQuote.find_by(stripe_invoice_id: invoice.id)
        return unless quote

        Rails.logger.warn("Stripe payment failed for quote #{quote.id}, invoice #{invoice.id}")

        quote.admin_user.log_action(
          "enterprise_quote_payment_failed",
          resource: quote,
          details: { invoice_id: invoice.id, user_email: quote.user.email }
        )
      end

      def handle_subscription_deleted
        stripe_sub = @event.data.object

        # Enterprise quote subscription
        quote = EnterpriseQuote.find_by(stripe_subscription_id: stripe_sub.id)
        if quote && !quote.cancelled?
          quote.update!(status: :cancelled)
          quote.admin_user.log_action(
            "enterprise_quote_cancelled",
            resource: quote,
            details: { subscription_id: stripe_sub.id, user_email: quote.user.email }
          )
          return
        end

        # Self-service subscription
        sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
        return unless sub
        return if sub.canceled?

        sub.update!(status: :canceled, canceled_at: Time.current)
      end

      # --- Self-service subscription handlers ---

      def handle_checkout_completed
        session = @event.data.object
        return unless session.mode == "subscription"

        user_id = session.metadata&.datakeep_user_id || session.metadata&.[]("datakeep_user_id")
        return unless user_id

        user = User.find_by(id: user_id)
        return unless user

        plan_tier = session.metadata&.plan_tier || session.metadata&.[]("plan_tier")
        billing_interval = session.metadata&.billing_interval || session.metadata&.[]("billing_interval")

        stripe_sub = ::Stripe::Subscription.retrieve(session.subscription)

        # Idempotency: don't create duplicate
        return if Subscription.exists?(stripe_subscription_id: stripe_sub.id)

        # Destroy any existing subscription for this user
        user.subscription&.destroy

        user.create_subscription!(
          plan_tier: plan_tier,
          billing_interval: billing_interval || "monthly",
          status: :active,
          stripe_subscription_id: stripe_sub.id,
          stripe_price_id: stripe_sub.items.data.first&.price&.id,
          current_period_end_epoch: stripe_sub.current_period_end
        )
      end

      def handle_subscription_updated
        stripe_sub = @event.data.object
        sub = Subscription.find_by(stripe_subscription_id: stripe_sub.id)
        return unless sub

        new_status = case stripe_sub.status
                     when "active" then :active
                     when "past_due" then :past_due
                     when "canceled" then :canceled
                     when "incomplete", "incomplete_expired" then :incomplete
                     else sub.status
                     end

        # Detect plan tier change from price
        price_id = stripe_sub.items.data.first&.price&.id
        tier_info = DataKeep::Stripe::StripePriceMapping.tier_from_price_id(price_id)

        attrs = {
          status: new_status,
          current_period_end_epoch: stripe_sub.current_period_end,
          cancel_at_period_end: stripe_sub.cancel_at_period_end,
          cancel_at: stripe_sub.cancel_at ? Time.at(stripe_sub.cancel_at).utc : nil,
          stripe_price_id: price_id
        }

        if tier_info
          attrs[:plan_tier] = tier_info[:plan_tier]
          attrs[:billing_interval] = tier_info[:billing_interval]
        end

        sub.update!(attrs)
      end
    end
  end
end
