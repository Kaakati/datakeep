# frozen_string_literal: true

class AddManagedToStorageBackends < ActiveRecord::Migration[8.1]
  def change
    add_column :storage_backends, :managed, :boolean, default: false, null: false
    add_index :storage_backends, :managed
    change_column_null :storage_backends, :user_id, true
    add_index :storage_backends, :name, unique: true, where: "managed = true",
              name: "index_storage_backends_on_name_managed"
  end
end
