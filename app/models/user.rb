# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :database_configs, dependent: :destroy
  has_many :storage_backends, dependent: :destroy
  has_many :backup_jobs, dependent: :destroy
  has_many :notification_channels, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password.present? }

  normalizes :email, with: ->(email) { email.strip.downcase }

  def log_action(action, resource: nil, details: nil, ip_address: nil)
    audit_logs.create!(
      action: action,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      details: details.is_a?(Hash) ? details.to_json : details,
      ip_address: ip_address
    )
  end
end
