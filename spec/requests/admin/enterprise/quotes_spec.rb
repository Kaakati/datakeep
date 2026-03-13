# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Enterprise::Quotes", type: :request do
  let(:admin) do
    User.create!(
      email: "admin-test@example.com",
      name: "Test Admin",
      password: "password123",
      password_confirmation: "password123",
      role: :admin
    )
  end

  before do
    PricingConfig.create!(key: "compression_ratios", value: { "postgresql" => 0.50, "mysql" => 0.25, "mongodb" => 0.30, "mssql" => 0.40, "oracle" => 0.40 })
    PricingConfig.create!(key: "retention_sets", value: { "hourly" => 175, "every_6h" => 35, "daily" => 14 })
    PricingConfig.create!(key: "s3_rates", value: { "standard" => 0.023, "standard_ia" => 0.0125, "glacier" => 0.004 })
    PricingConfig.create!(key: "platform_base_fee_cents", value: { "amount" => 5000 })
    PricingConfig.create!(key: "per_db_fee_cents", value: { "amount" => 500 })
    PricingConfig.create!(key: "max_discount_percent", value: { "amount" => 40 })
    Rails.cache.clear
  end

  describe "GET /admin/enterprise/quote" do
    it "renders the quote form" do
      post login_path, params: { email: admin.email, password: "password123" }
      get admin_enterprise_quote_calculator_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Enterprise Pricing Calculator")
    end
  end

  describe "POST /admin/enterprise/quote" do
    it "returns results with valid params" do
      post login_path, params: { email: admin.email, password: "password123" }
      post admin_enterprise_quote_calculator_path, params: {
        databases: {
          "0" => { name: "Production", engine: "postgresql", size_gb: "50", frequency: "hourly" }
        },
        retention_days: "30",
        regions: "2",
        discount_percent: "10"
      }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Quote Breakdown")
      expect(response.body).to include("Production")
    end

    it "shows error for discount > 40%" do
      post login_path, params: { email: admin.email, password: "password123" }
      post admin_enterprise_quote_calculator_path, params: {
        databases: {
          "0" => { name: "Production", engine: "postgresql", size_gb: "50", frequency: "hourly" }
        },
        retention_days: "30",
        regions: "1",
        discount_percent: "50"
      }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("cannot exceed 40%")
    end
  end
end
