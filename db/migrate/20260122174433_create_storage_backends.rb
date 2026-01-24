class CreateStorageBackends < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_backends do |t|
      t.references :user, null: false, foreign_key: true
      t.string :type, null: false
      t.string :name, null: false
      t.text :encrypted_config
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end
    add_index :storage_backends, [ :user_id, :name ], unique: true
  end
end
