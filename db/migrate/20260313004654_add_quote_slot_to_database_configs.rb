# frozen_string_literal: true

class AddQuoteSlotToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_reference :database_configs, :enterprise_quote, foreign_key: true, null: true
    add_column :database_configs, :quote_database_index, :integer, null: true
    add_index :database_configs, [:enterprise_quote_id, :quote_database_index],
              unique: true,
              where: "enterprise_quote_id IS NOT NULL",
              name: "idx_database_configs_on_quote_slot"
  end
end
