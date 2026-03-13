# frozen_string_literal: true

module Admin
  module Enterprise
    class QuoteCalculatorController < Admin::BaseController
      def show
        @result = nil
      end

      def create
        databases = parse_databases
        @result = DataKeep::EnterpriseQuoteCalculator.call(
          databases: databases,
          retention_days: params[:retention_days],
          regions: params[:regions],
          discount_percent: params[:discount_percent]
        )

        render :show
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
