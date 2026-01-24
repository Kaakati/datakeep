class CreateHealthChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :health_checks do |t|
      t.references :database_config, null: false, foreign_key: true
      t.string :status, null: false, default: "unknown"
      t.datetime :checked_at, null: false
      t.integer :response_time_ms
      t.text :error_message

      t.timestamps
    end

    add_index :health_checks, :checked_at
    add_index :health_checks, :status
    add_index :health_checks, [:database_config_id, :checked_at]
  end
end
