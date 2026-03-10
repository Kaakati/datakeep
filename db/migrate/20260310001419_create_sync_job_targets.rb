class CreateSyncJobTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_job_targets do |t|
      t.references :sync_job, null: false, foreign_key: true
      t.references :database_config, null: false, foreign_key: true

      t.timestamps
    end

    add_index :sync_job_targets, [ :sync_job_id, :database_config_id ], unique: true
  end
end
