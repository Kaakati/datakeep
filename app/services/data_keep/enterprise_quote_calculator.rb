# frozen_string_literal: true

module DataKeep
  class EnterpriseQuoteCalculator
    LineItem = Struct.new(
      :name, :engine, :raw_size_gb, :compressed_gb, :total_stored_gb,
      :storage_cost_cents, :regions, :line_total_cents,
      keyword_init: true
    )

    Result = Struct.new(
      :line_items, :platform_fee_cents, :subtotal_cents, :discount_percent,
      :discount_amount_cents, :total_monthly_cents, :annual_contract_value_cents,
      :savings_amount_cents,
      keyword_init: true
    )

    Error = Struct.new(:message, keyword_init: true)

    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @databases = params[:databases] || []
      @retention_days = (params[:retention_days] || 30).to_i
      @regions = (params[:regions] || 1).to_i
      @discount_percent = (params[:discount_percent] || 0).to_f
    end

    def call
      max_discount = PricingConfig.cached_get("max_discount_percent")["amount"]
      if @discount_percent > max_discount
        return Error.new(message: "Discount cannot exceed #{max_discount}%")
      end

      compression_ratios = PricingConfig.cached_get("compression_ratios")
      retention_sets = PricingConfig.cached_get("retention_sets")
      s3_rates = PricingConfig.cached_get("s3_rates")

      line_items = @databases.map do |db|
        engine = db[:engine].to_s
        size_gb = db[:size_gb].to_f
        frequency = db[:frequency].to_s

        ratio = compression_ratios[engine] || 0.40
        compressed_gb = size_gb * ratio

        sets = retention_sets[frequency] || 14
        total_stored_gb = compressed_gb * sets

        storage_cost_per_gb = tiered_cost_per_gb(s3_rates, @retention_days)
        storage_cost_cents = (total_stored_gb * storage_cost_per_gb * 100).round

        line_total_cents = storage_cost_cents * @regions

        LineItem.new(
          name: db[:name],
          engine: engine,
          raw_size_gb: size_gb,
          compressed_gb: compressed_gb.round(2),
          total_stored_gb: total_stored_gb.round(2),
          storage_cost_cents: storage_cost_cents,
          regions: @regions,
          line_total_cents: line_total_cents
        )
      end

      platform_base = PricingConfig.cached_get("platform_base_fee_cents")["amount"]
      per_db = PricingConfig.cached_get("per_db_fee_cents")["amount"]
      platform_fee_cents = platform_base + (@databases.size * per_db)

      subtotal_cents = platform_fee_cents + line_items.sum(&:line_total_cents)
      discount_amount_cents = (subtotal_cents * @discount_percent / 100.0).round
      total_monthly_cents = subtotal_cents - discount_amount_cents

      Result.new(
        line_items: line_items,
        platform_fee_cents: platform_fee_cents,
        subtotal_cents: subtotal_cents,
        discount_percent: @discount_percent,
        discount_amount_cents: discount_amount_cents,
        total_monthly_cents: total_monthly_cents,
        annual_contract_value_cents: total_monthly_cents * 12,
        savings_amount_cents: discount_amount_cents * 12
      )
    end

    private

    def tiered_cost_per_gb(s3_rates, retention_days)
      standard = s3_rates["standard"]
      standard_ia = s3_rates["standard_ia"]
      glacier = s3_rates["glacier"]

      if retention_days <= 7
        standard
      elsif retention_days <= 90
        standard_portion = 7.0 / retention_days
        ia_portion = 1.0 - standard_portion
        (standard * standard_portion) + (standard_ia * ia_portion)
      else
        standard_portion = 7.0 / retention_days
        ia_portion = 83.0 / retention_days
        glacier_portion = 1.0 - standard_portion - ia_portion
        (standard * standard_portion) + (standard_ia * ia_portion) + (glacier * glacier_portion)
      end
    end
  end
end
