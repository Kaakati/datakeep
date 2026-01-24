class CreateRestores < ActiveRecord::Migration[8.1]
  def change
    create_table :restores do |t|
      t.references :user, null: false, foreign_key: true
      t.references :database_config, null: false, foreign_key: true
      t.references :backup, null: true, foreign_key: true
      t.string :file_path
      t.string :status, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :restores, :status
  end
end
