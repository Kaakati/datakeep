# frozen_string_literal: true

class AddSshFieldsToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :database_configs, :ssh_host, :string
    add_column :database_configs, :ssh_port, :integer, default: 22
    add_column :database_configs, :ssh_user, :string
    add_column :database_configs, :ssh_private_key, :text
  end
end
