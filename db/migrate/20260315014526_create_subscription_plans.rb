# frozen_string_literal: true

class CreateSubscriptionPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_plans do |t|
      t.string  :tier_key, null: false
      t.string  :name, null: false
      t.integer :monthly_price_cents, null: false, default: 0
      t.integer :annual_price_cents, null: false, default: 0
      t.string  :stripe_product_id
      t.string  :stripe_monthly_price_id
      t.string  :stripe_annual_price_id
      t.boolean :enabled, null: false, default: true
      t.jsonb   :limits, null: false, default: {}
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end

    add_index :subscription_plans, :tier_key, unique: true
    add_index :subscription_plans, :enabled
  end
end
