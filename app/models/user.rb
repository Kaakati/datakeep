# frozen_string_literal: true

class User < ApplicationRecord
  include PlanTierLimits

  has_secure_password validations: false

  enum :role, { user: 0, admin: 1 }, default: :user

  has_many :database_configs, dependent: :destroy
  has_many :storage_backends, dependent: :destroy
  has_many :backup_jobs, dependent: :destroy
  has_many :sync_jobs, dependent: :destroy
  has_many :notification_channels, dependent: :destroy
  has_many :enterprise_quotes
  has_many :audit_logs, dependent: :nullify
  has_one  :subscription, dependent: :destroy

  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, if: :password_required?

  normalizes :email, with: ->(email) { email.strip.downcase }

  def available_storage_backends
    StorageBackend.where("user_id = ? OR managed = true", id)
  end

  # --- Plan & Billing ---

  def active_enterprise_quote
    @active_enterprise_quote ||= enterprise_quotes.where(status: :paid).order(created_at: :desc).first
  end

  def enterprise_plan?
    active_enterprise_quote.present?
  end

  def active_subscription
    @active_subscription ||= subscription if subscription&.active_access?
  end

  def plan_tier_key
    return :enterprise if enterprise_plan?
    return active_subscription.plan_tier.to_sym if active_subscription
    :free
  end

  def free_plan?
    plan_tier_key == :free
  end

  def plan_name
    return "Enterprise" if enterprise_plan?
    TIER_DEFINITIONS.dig(plan_tier_key, :label) || "Free"
  end

  def plan_limits
    if enterprise_plan?
      quote = active_enterprise_quote
      databases = quote.quote_params["databases"] || []
      retention = (quote.quote_params["retention_days"] || 365).to_i
      {
        max_database_configs: databases.size,
        max_backup_jobs: nil,
        max_storage_backends: nil,
        max_notification_channels: nil,
        max_retention_days: retention,
        s3_allowed: true,
        default_size_gb: nil
      }
    else
      tier = TIER_DEFINITIONS[plan_tier_key] || TIER_DEFINITIONS[:free]
      {
        max_database_configs: tier[:max_database_configs],
        max_backup_jobs: tier[:max_backup_jobs],
        max_storage_backends: tier[:max_storage_backends],
        max_notification_channels: tier[:max_notification_channels],
        max_retention_days: tier[:max_retention_days],
        s3_allowed: tier[:s3_allowed],
        default_size_gb: tier[:max_storage_gb]
      }
    end
  end

  def can_create?(resource_type)
    limit = plan_limits[:"max_#{resource_type}s"]
    return true if limit.nil? # unlimited
    send(:"#{resource_type}s").count < limit
  end

  def resource_usage
    {
      database_configs: database_configs.count,
      backup_jobs: backup_jobs.count,
      storage_backends: storage_backends.count,
      notification_channels: notification_channels.count
    }
  end

  def available_quote_slots
    return [] unless enterprise_plan?

    databases = active_enterprise_quote.quote_params["databases"] || []
    assigned = database_configs.where.not(enterprise_quote_id: nil).pluck(:quote_database_index)

    databases.each_with_index.filter_map do |db, idx|
      next if assigned.include?(idx)
      { index: idx, name: db["name"], engine: db["engine"], size_gb: db["size_gb"].to_f }
    end
  end

  def oauth_user?
    provider.present?
  end

  def self.find_or_create_from_oauth(auth_hash)
    info = auth_hash["info"]
    find_by(provider: auth_hash["provider"], uid: auth_hash["uid"]) ||
      find_by(email: info["email"])&.tap { |u|
        u.update!(provider: auth_hash["provider"], uid: auth_hash["uid"], avatar_url: info["image"])
      } ||
      create!(
        email: info["email"],
        name: info["name"],
        provider: auth_hash["provider"],
        uid: auth_hash["uid"],
        avatar_url: info["image"]
      )
  end

  def log_action(action, resource: nil, details: nil, ip_address: nil)
    audit_logs.create!(
      action: action,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      details: details.is_a?(Hash) ? details.to_json : details,
      ip_address: ip_address
    )
  end

  private

  def password_required?
    return false if oauth_user?
    new_record? || password.present?
  end
end
