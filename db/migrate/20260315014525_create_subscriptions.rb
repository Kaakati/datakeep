# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.integer    :plan_tier, null: false, default: 0
      t.integer    :billing_interval, null: false, default: 0
      t.integer    :status, null: false, default: 0
      t.string     :stripe_subscription_id
      t.string     :stripe_price_id
      t.integer    :current_period_end_epoch
      t.datetime   :cancel_at
      t.boolean    :cancel_at_period_end, default: false, null: false
      t.datetime   :canceled_at
      t.timestamps
    end

    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, [:user_id, :status]
  end
end
