class CreateSyncJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :source_database_config, null: false, foreign_key: { to_table: :database_configs }
      t.string :name, null: false
      t.integer :interval_minutes, null: false, default: 60
      t.boolean :enabled, null: false, default: true
      t.string :status, null: false, default: "idle"
      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end

    add_index :sync_jobs, [ :user_id, :name ], unique: true
    add_index :sync_jobs, :next_run_at
    add_index :sync_jobs, :enabled
  end
end
