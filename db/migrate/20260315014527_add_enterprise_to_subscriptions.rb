# frozen_string_literal: true

class AddEnterpriseToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :enterprise_quote_id, :bigint, null: true
    add_index  :subscriptions, :enterprise_quote_id
    add_foreign_key :subscriptions, :enterprise_quotes

    add_column :enterprise_quotes, :stripe_product_id, :string
  end
end
