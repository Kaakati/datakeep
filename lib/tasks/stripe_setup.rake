# frozen_string_literal: true

namespace :stripe do
  desc "Create Stripe Products and Prices for DataKeep subscription tiers"
  task setup_products: :environment do
    require "stripe"

    product = Stripe::Product.create(
      name: "DataKeep",
      description: "Database backup, sync, and monitoring platform"
    )

    puts "Created Product: #{product.id}"
    puts ""

    tiers = {
      starter: { monthly: 3_900, annual: 37_440, label: "Starter" },
      professional: { monthly: 9_900, annual: 95_040, label: "Professional" },
      business: { monthly: 29_900, annual: 287_040, label: "Business" }
    }

    tiers.each do |tier_key, config|
      monthly_price = Stripe::Price.create(
        product: product.id,
        unit_amount: config[:monthly],
        currency: "usd",
        recurring: { interval: "month" },
        lookup_key: "datakeep_#{tier_key}_monthly",
        metadata: { tier: tier_key, interval: "monthly" }
      )

      annual_price = Stripe::Price.create(
        product: product.id,
        unit_amount: config[:annual],
        currency: "usd",
        recurring: { interval: "year" },
        lookup_key: "datakeep_#{tier_key}_annual",
        metadata: { tier: tier_key, interval: "annual" }
      )

      puts "#{config[:label]}:"
      puts "  STRIPE_PRICE_#{tier_key.upcase}_MONTHLY=#{monthly_price.id}"
      puts "  STRIPE_PRICE_#{tier_key.upcase}_ANNUAL=#{annual_price.id}"
      puts ""
    end

    puts "Add these environment variables to your .env or secrets manager."
  end
end
