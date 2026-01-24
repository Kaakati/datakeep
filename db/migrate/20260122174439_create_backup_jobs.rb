class CreateBackupJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_jobs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :database_config, null: false, foreign_key: true
      t.references :storage_backend, null: false, foreign_key: true
      t.string :name, null: false
      t.string :schedule_type, null: false, default: "daily"
      t.string :cron_expression
      t.boolean :compression, default: true, null: false
      t.boolean :encryption, default: false, null: false
      t.integer :retention_days, default: 30, null: false
      t.string :status, default: "idle", null: false
      t.datetime :last_run_at
      t.datetime :next_run_at
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end
    add_index :backup_jobs, [ :user_id, :name ], unique: true
    add_index :backup_jobs, :next_run_at
    add_index :backup_jobs, :enabled
  end
end
