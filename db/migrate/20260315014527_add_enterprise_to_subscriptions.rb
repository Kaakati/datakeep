# frozen_string_literal: true

class AddEnterpriseToSubscriptions < ActiveRecord::Migration[8.1]
  # Originally 20260315003416, renamed to fix ordering.
  # Made idempotent since production already ran the original version.
  def change
    unless column_exists?(:subscriptions, :enterprise_quote_id)
      add_column :subscriptions, :enterprise_quote_id, :bigint, null: true
    end

    unless index_exists?(:subscriptions, :enterprise_quote_id)
      add_index :subscriptions, :enterprise_quote_id
    end

    unless foreign_key_exists?(:subscriptions, :enterprise_quotes)
      add_foreign_key :subscriptions, :enterprise_quotes
    end

    unless column_exists?(:enterprise_quotes, :stripe_product_id)
      add_column :enterprise_quotes, :stripe_product_id, :string
    end
  end
end
