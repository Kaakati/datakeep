class CreatePricingConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :pricing_configs do |t|
      t.string :key, null: false
      t.jsonb :value, null: false, default: {}
      t.string :description

      t.timestamps
    end

    add_index :pricing_configs, :key, unique: true
  end
end
