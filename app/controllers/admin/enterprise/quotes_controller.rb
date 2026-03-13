# frozen_string_literal: true

module Admin
  module Enterprise
    class QuotesController < Admin::BaseController
      def index
        @quotes = EnterpriseQuote.recent.includes(:user, :admin_user)
      end

      def show
        @quote = EnterpriseQuote.find(params[:id])
        @result = @quote.calculator_result
      end

      def create
        databases = parse_databases
        result = DataKeep::EnterpriseQuoteCalculator.call(
          databases: databases,
          retention_days: params[:retention_days],
          regions: params[:regions],
          discount_percent: params[:discount_percent]
        )

        if result.is_a?(DataKeep::EnterpriseQuoteCalculator::Error)
          redirect_to admin_enterprise_quote_calculator_path, alert: result.message
          return
        end

        quote = EnterpriseQuote.create!(
          admin_user: current_user,
          user_id: params[:user_id],
          quote_params: {
            databases: databases,
            retention_days: params[:retention_days],
            regions: params[:regions],
            discount_percent: params[:discount_percent]
          },
          line_items_snapshot: result.to_h.merge(
            line_items: result.line_items.map(&:to_h)
          ),
          total_monthly_cents: result.total_monthly_cents,
          discount_percent: result.discount_percent
        )

        redirect_to admin_enterprise_quote_path(quote), notice: "Quote saved as draft."
      end

      def send_invoice
        @quote = EnterpriseQuote.find(params[:id])

        unless @quote.draft?
          redirect_to admin_enterprise_quote_path(@quote), alert: "Only draft quotes can be sent."
          return
        end

        StripeInvoiceJob.perform_later(@quote)
        redirect_to admin_enterprise_quote_path(@quote), notice: "Invoice is being sent via Stripe."
      end

      private

      def parse_databases
        return [] unless params[:databases].present?

        params[:databases].values.map do |db|
          next if db[:name].blank? && db[:size_gb].blank?
          {
            name: db[:name],
            engine: db[:engine],
            size_gb: db[:size_gb],
            frequency: db[:frequency]
          }
        end.compact
      end
    end
  end
end
