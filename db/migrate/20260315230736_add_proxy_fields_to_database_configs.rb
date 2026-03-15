# frozen_string_literal: true

class AddProxyFieldsToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :database_configs, :proxy_type, :string
    add_column :database_configs, :proxy_host, :string
    add_column :database_configs, :proxy_port, :integer
    add_column :database_configs, :proxy_username, :string
    add_column :database_configs, :proxy_password, :text
  end
end
