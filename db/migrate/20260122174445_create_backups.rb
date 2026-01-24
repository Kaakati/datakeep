class CreateBackups < ActiveRecord::Migration[8.1]
  def change
    create_table :backups do |t|
      t.references :backup_job, null: false, foreign_key: true
      t.references :storage_backend, null: false, foreign_key: true
      t.string :file_path
      t.string :file_name, null: false
      t.bigint :file_size
      t.string :checksum
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.string :pg_version
      t.string :database_name
      t.boolean :encrypted, default: false, null: false
      t.boolean :compressed, default: false, null: false

      t.timestamps
    end
    add_index :backups, :status
    add_index :backups, :created_at
  end
end
