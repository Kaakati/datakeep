# frozen_string_literal: true

class AddOauthFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :password_digest, true
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :avatar_url, :string
    add_index :users, [:provider, :uid], unique: true, where: "provider IS NOT NULL"
  end
end
