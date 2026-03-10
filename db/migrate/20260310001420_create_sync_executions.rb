class CreateSyncExecutions < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_executions do |t|
      t.references :sync_job, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :targets_count, default: 0
      t.integer :targets_succeeded, default: 0
      t.text :error_message

      t.timestamps
    end

    add_index :sync_executions, :status
    add_index :sync_executions, :created_at
  end
end
