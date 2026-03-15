# frozen_string_literal: true

class AddOtpRequiredToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :otp_required, :boolean, default: false, null: false
  end
end
