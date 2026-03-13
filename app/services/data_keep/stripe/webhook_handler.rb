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
        else
          Rails.logger.info("Unhandled Stripe event: #{@event.type}")
        end
      end

      private

      def handle_invoice_paid
        invoice = @event.data.object
        quote = EnterpriseQuote.find_by(stripe_invoice_id: invoice.id)
        return unless quote
        return if quote.paid? # idempotent

        quote.update!(status: :paid, paid_at: Time.current)

        # Create recurring subscription
        SubscriptionService.create_from_quote(enterprise_quote: quote)

        # Audit log
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
        subscription = @event.data.object
        quote = EnterpriseQuote.find_by(stripe_subscription_id: subscription.id)
        return unless quote
        return if quote.cancelled?

        quote.update!(status: :cancelled)

        quote.admin_user.log_action(
          "enterprise_quote_cancelled",
          resource: quote,
          details: { subscription_id: subscription.id, user_email: quote.user.email }
        )
      end
    end
  end
end
