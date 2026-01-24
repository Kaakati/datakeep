class CreateNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channels do |t|
      t.references :user, null: false, foreign_key: true
      t.string :type, null: false
      t.string :name, null: false
      t.text :encrypted_config
      t.boolean :enabled, default: true, null: false
      t.boolean :notify_on_success, default: false, null: false
      t.boolean :notify_on_failure, default: true, null: false

      t.timestamps
    end
    add_index :notification_channels, [ :user_id, :name ], unique: true
  end
end
