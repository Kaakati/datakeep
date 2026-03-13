# Admin user
admin = User.find_or_initialize_by(email: "admin@example.com")
admin.assign_attributes(
  name: "Admin",
  password: "password123",
  password_confirmation: "password123",
  role: :admin
)
admin.save!
puts "Admin user created: admin@example.com"

# Pricing Configs
PricingConfig.find_or_create_by!(key: "compression_ratios") do |pc|
  pc.value = { postgresql: 0.50, mysql: 0.25, mongodb: 0.30, mssql: 0.40, oracle: 0.40 }
  pc.description = "Backup compression ratio per engine (fraction of raw size)"
end
PricingConfig.find_or_create_by!(key: "retention_sets") do |pc|
  pc.value = { hourly: 175, every_6h: 35, daily: 14 }
  pc.description = "Number of retained backup sets per frequency (7 daily + 4 weekly + 3 monthly = 14)"
end
PricingConfig.find_or_create_by!(key: "s3_rates") do |pc|
  pc.value = { standard: 0.023, standard_ia: 0.0125, glacier: 0.004 }
  pc.description = "S3 storage cost per GB/month by tier (USD)"
end
PricingConfig.find_or_create_by!(key: "platform_base_fee_cents") do |pc|
  pc.value = { amount: 5000 }
  pc.description = "Monthly platform base fee in cents ($50)"
end
PricingConfig.find_or_create_by!(key: "per_db_fee_cents") do |pc|
  pc.value = { amount: 500 }
  pc.description = "Monthly per-database fee in cents ($5)"
end
PricingConfig.find_or_create_by!(key: "max_discount_percent") do |pc|
  pc.value = { amount: 40 }
  pc.description = "Maximum allowed discount percentage for enterprise quotes"
end
puts "Pricing configs seeded"
