class AddDatabaseTypeToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :database_configs, :database_type, :string, default: "postgresql", null: false
    add_index :database_configs, :database_type
  end
end
