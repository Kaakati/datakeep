# frozen_string_literal: true

class AddVpnFieldsToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :database_configs, :vpn_enabled, :boolean, default: false, null: false
    add_column :database_configs, :vpn_type, :string
    add_column :database_configs, :vpn_config_data, :text
    add_column :database_configs, :vpn_gateway_ip, :string
    add_column :database_configs, :vpn_tunnel_name, :string

    add_index :database_configs, :vpn_enabled
  end
end
