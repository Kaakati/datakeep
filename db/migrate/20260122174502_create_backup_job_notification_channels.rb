class CreateBackupJobNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_job_notification_channels do |t|
      t.references :backup_job, null: false, foreign_key: true
      t.references :notification_channel, null: false, foreign_key: true

      t.timestamps
    end
    add_index :backup_job_notification_channels, [ :backup_job_id, :notification_channel_id ], unique: true, name: "idx_backup_job_notification_channel_unique"
  end
end
