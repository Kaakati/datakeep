# frozen_string_literal: true

class CreateCoupons < ActiveRecord::Migration[8.0]
  def change
    create_table :coupons do |t|
      t.string  :code, null: false
      t.integer :discount_type, null: false, default: 0
      t.integer :discount_value, null: false
      t.string  :currency, default: "usd"
      t.integer :duration, null: false, default: 0
      t.integer :duration_in_months
      t.integer :max_redemptions
      t.integer :redemptions_count, null: false, default: 0
      t.datetime :expires_at
      t.string  :applicable_plans, default: "all"
      t.boolean :active, null: false, default: true
      t.string  :stripe_coupon_id

      t.timestamps
    end

    add_index :coupons, :code, unique: true
    add_index :coupons, :stripe_coupon_id, unique: true
    add_index :coupons, :active
  end
end
