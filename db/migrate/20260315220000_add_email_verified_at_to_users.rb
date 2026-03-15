# frozen_string_literal: true

class AddEmailVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime
    User.unscoped.update_all("email_verified_at = created_at")
  end

  def down
    remove_column :users, :email_verified_at
  end
end
