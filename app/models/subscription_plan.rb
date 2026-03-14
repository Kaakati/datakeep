# frozen_string_literal: true

class SubscriptionPlan < ApplicationRecord
  include PlanTierLimits

  VALID_TIER_KEYS = %w[starter professional business].freeze

  # == Validations ==========================================================
  validates :tier_key, presence: true, uniqueness: true, inclusion: { in: VALID_TIER_KEYS }
  validates :name, presence: true
  validates :monthly_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :annual_price_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :sort_order, numericality: { only_integer: true }

  # == Scopes ===============================================================
  scope :enabled, -> { where(enabled: true) }
  scope :sorted, -> { order(sort_order: :asc) }

  # == Class Methods ========================================================
  def self.for_tier(tier_key)
    find_by(tier_key: tier_key.to_s)
  end

  def self.enabled_paid_tiers
    enabled.sorted.to_a
  end

  # == Instance Methods =====================================================
  def stripe_synced?
    stripe_product_id.present? &&
      stripe_monthly_price_id.present? &&
      stripe_annual_price_id.present?
  end

  def price_id_for(interval)
    case interval.to_s
    when "monthly" then stripe_monthly_price_id
    when "annual" then stripe_annual_price_id
    end
  end

  def merged_limits
    defaults = TIER_DEFINITIONS[tier_key.to_sym] || {}
    defaults.merge(limits.symbolize_keys).merge(
      label: name,
      monthly_price_cents: monthly_price_cents,
      annual_price_cents: annual_price_cents
    )
  end

  def annual_savings_percent
    return 0 if monthly_price_cents.zero?
    ((1.0 - annual_price_cents.to_f / (monthly_price_cents * 12)) * 100).round
  end
end
