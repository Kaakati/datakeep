# frozen_string_literal: true

class CreateEnterpriseQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :enterprise_quotes do |t|
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.references :user, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.jsonb :quote_params, null: false
      t.jsonb :line_items_snapshot, null: false
      t.integer :total_monthly_cents, null: false
      t.float :discount_percent, default: 0
      t.string :currency, default: "usd"
      t.string :stripe_invoice_id
      t.string :stripe_subscription_id
      t.string :stripe_coupon_id
      t.datetime :sent_at
      t.datetime :paid_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :enterprise_quotes, :stripe_invoice_id, unique: true
    add_index :enterprise_quotes, :stripe_subscription_id, unique: true
    add_index :enterprise_quotes, :status
  end
end
