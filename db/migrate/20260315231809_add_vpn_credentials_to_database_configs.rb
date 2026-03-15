# frozen_string_literal: true

class AddVpnCredentialsToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :database_configs, :vpn_preshared_key, :text
    add_column :database_configs, :vpn_username, :string
    add_column :database_configs, :vpn_password, :text
  end
end
