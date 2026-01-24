class CreateDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :database_configs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :host, null: false
      t.integer :port, null: false, default: 5432
      t.string :database_name, null: false
      t.string :username, null: false
      t.text :encrypted_password
      t.string :ssl_mode, default: "prefer"
      t.string :pg_version
      t.datetime :last_health_check_at
      t.string :health_status, default: "unknown"

      t.timestamps
    end
    add_index :database_configs, [ :user_id, :name ], unique: true
  end
end
