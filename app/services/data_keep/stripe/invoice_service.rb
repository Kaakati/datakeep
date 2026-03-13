# frozen_string_literal: true

module DataKeep
  module Stripe
    class InvoiceService
      def initialize(enterprise_quote)
        @quote = enterprise_quote
      end

      def create_and_send
        return { success: true, invoice_id: @quote.stripe_invoice_id } if @quote.stripe_invoice_id.present?

        customer_id = CustomerService.find_or_create(user: @quote.user)
        result = @quote.calculator_result

        # Create invoice
        invoice_params = {
          customer: customer_id,
          currency: @quote.currency,
          collection_method: "send_invoice",
          days_until_due: 30,
          metadata: { enterprise_quote_id: @quote.id }
        }

        # Create coupon and apply discount if present
        if @quote.discount_percent.to_f > 0
          coupon = ::Stripe::Coupon.create(
            percent_off: @quote.discount_percent,
            duration: "repeating",
            duration_in_months: 12,
            name: "Enterprise Discount #{@quote.discount_percent.to_i}%"
          )
          invoice_params[:discounts] = [ { coupon: coupon.id } ]
          @quote.stripe_coupon_id = coupon.id
        end

        invoice = ::Stripe::Invoice.create(invoice_params)

        # Add line items: one per database
        result.line_items.each do |item|
          ::Stripe::InvoiceItem.create(
            customer: customer_id,
            invoice: invoice.id,
            amount: item.line_total_cents,
            currency: @quote.currency,
            description: "#{item.name} (#{item.engine.titleize}) - #{item.raw_size_gb}GB, #{item.regions}x region(s)"
          )
        end

        # Add platform fee
        ::Stripe::InvoiceItem.create(
          customer: customer_id,
          invoice: invoice.id,
          amount: result.platform_fee_cents,
          currency: @quote.currency,
          description: "DataKeep Enterprise Platform Fee"
        )

        # Finalize and send
        invoice = ::Stripe::Invoice.finalize_invoice(invoice.id)
        invoice = ::Stripe::Invoice.send_invoice(invoice.id)

        @quote.update!(
          stripe_invoice_id: invoice.id,
          stripe_hosted_invoice_url: invoice.hosted_invoice_url,
          status: :sent,
          sent_at: Time.current,
          expires_at: 30.days.from_now
        )

        { success: true, invoice_id: invoice.id }
      rescue ::Stripe::StripeError => e
        { success: false, error: e.message }
      end
    end
  end
end
