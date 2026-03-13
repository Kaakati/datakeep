# frozen_string_literal: true

require "rails_helper"

RSpec.describe DataKeep::EnterpriseQuoteCalculator do
  before do
    PricingConfig.find_or_create_by!(key: "compression_ratios") do |pc|
      pc.value = { "postgresql" => 0.50, "mysql" => 0.25, "mongodb" => 0.30, "mssql" => 0.40, "oracle" => 0.40 }
    end
    PricingConfig.find_or_create_by!(key: "retention_sets") do |pc|
      pc.value = { "hourly" => 175, "every_6h" => 35, "daily" => 14 }
    end
    PricingConfig.find_or_create_by!(key: "s3_rates") do |pc|
      pc.value = { "standard" => 0.023, "standard_ia" => 0.0125, "glacier" => 0.004 }
    end
    PricingConfig.find_or_create_by!(key: "platform_base_fee_cents") do |pc|
      pc.value = { "amount" => 5000 }
    end
    PricingConfig.find_or_create_by!(key: "per_db_fee_cents") do |pc|
      pc.value = { "amount" => 500 }
    end
    PricingConfig.find_or_create_by!(key: "max_discount_percent") do |pc|
      pc.value = { "amount" => 40 }
    end
    Rails.cache.clear
  end

  def build_params(databases:, retention_days: 30, regions: 1, discount_percent: 0)
    { databases: databases, retention_days: retention_days, regions: regions, discount_percent: discount_percent }
  end

  describe "compression ratios" do
    %w[postgresql mysql mongodb mssql oracle].each do |engine|
      it "applies #{engine} compression ratio" do
        expected_ratios = { "postgresql" => 0.50, "mysql" => 0.25, "mongodb" => 0.30, "mssql" => 0.40, "oracle" => 0.40 }
        params = build_params(databases: [ { name: "Test", engine: engine, size_gb: 100, frequency: "daily" } ])
        result = described_class.call(params)
        item = result.line_items.first
        expect(item.compressed_gb).to eq((100 * expected_ratios[engine]).round(2))
      end
    end
  end

  describe "tiered storage allocation" do
    it "uses Standard only for retention <= 7 days" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], retention_days: 7)
      result = described_class.call(params)
      # 100 * 0.50 = 50 compressed, 50 * 14 sets = 700 stored, 700 * 0.023 = $16.10 = 1610 cents
      expect(result.line_items.first.storage_cost_cents).to eq(1610)
    end

    it "splits Standard/Standard-IA for retention 8-90 days" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], retention_days: 30)
      result = described_class.call(params)
      # Blended rate: (7/30)*0.023 + (23/30)*0.0125 = 0.005367 + 0.009583 = 0.01495
      # 700 * 0.01495 = $10.465 ~ 1046 cents (floating point rounding)
      expect(result.line_items.first.storage_cost_cents).to eq(1046)
    end

    it "splits Standard/Standard-IA/Glacier for retention > 90 days" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], retention_days: 180)
      result = described_class.call(params)
      # Blended: (7/180)*0.023 + (83/180)*0.0125 + (90/180)*0.004
      # = 0.000894 + 0.005764 + 0.002 = 0.008658
      # 700 * 0.008658 = $6.061 = 606 cents
      expect(result.line_items.first.storage_cost_cents).to eq(606)
    end
  end

  describe "region multiplier" do
    it "multiplies storage cost by regions" do
      params1 = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], regions: 1)
      params3 = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], regions: 3)
      result1 = described_class.call(params1)
      result3 = described_class.call(params3)
      expect(result3.line_items.first.line_total_cents).to eq(result1.line_items.first.line_total_cents * 3)
    end
  end

  describe "discount" do
    it "applies 0% discount correctly" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], discount_percent: 0)
      result = described_class.call(params)
      expect(result.discount_amount_cents).to eq(0)
      expect(result.total_monthly_cents).to eq(result.subtotal_cents)
    end

    it "applies 20% discount correctly" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], discount_percent: 20)
      result = described_class.call(params)
      expect(result.discount_amount_cents).to eq((result.subtotal_cents * 0.20).round)
      expect(result.total_monthly_cents).to eq(result.subtotal_cents - result.discount_amount_cents)
    end

    it "applies 40% discount correctly" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], discount_percent: 40)
      result = described_class.call(params)
      expect(result.discount_amount_cents).to eq((result.subtotal_cents * 0.40).round)
      expect(result.total_monthly_cents).to eq(result.subtotal_cents - result.discount_amount_cents)
    end

    it "rejects discount > 40%" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], discount_percent: 50)
      result = described_class.call(params)
      expect(result).to be_a(DataKeep::EnterpriseQuoteCalculator::Error)
      expect(result.message).to include("40%")
    end
  end

  describe "annual calculations" do
    it "calculates annual_contract_value as total_monthly * 12" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], discount_percent: 15)
      result = described_class.call(params)
      expect(result.annual_contract_value_cents).to eq(result.total_monthly_cents * 12)
    end

    it "calculates savings_amount as discount_amount * 12" do
      params = build_params(databases: [ { name: "Test", engine: "postgresql", size_gb: 100, frequency: "daily" } ], discount_percent: 15)
      result = described_class.call(params)
      expect(result.savings_amount_cents).to eq(result.discount_amount_cents * 12)
    end
  end

  describe "platform fees" do
    it "includes base fee plus per-db fee" do
      params = build_params(databases: [
        { name: "DB1", engine: "postgresql", size_gb: 50, frequency: "hourly" },
        { name: "DB2", engine: "mysql", size_gb: 20, frequency: "daily" },
        { name: "DB3", engine: "mongodb", size_gb: 30, frequency: "every_6h" }
      ])
      result = described_class.call(params)
      # 5000 base + 3 * 500 = 6500
      expect(result.platform_fee_cents).to eq(6500)
    end
  end
end
