# frozen_string_literal: true

class Subscription < ApplicationRecord
  # == Enums ================================================================
  enum :plan_tier, { free: 0, starter: 1, professional: 2, business: 3 }
  enum :billing_interval, { monthly: 0, annual: 1 }
  enum :status, { active: 0, past_due: 1, canceled: 2, incomplete: 3 }

  # == Associations =========================================================
  belongs_to :user

  # == Validations ==========================================================
  validates :plan_tier, presence: true
  validates :billing_interval, presence: true
  validates :status, presence: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true

  # == Instance Methods =====================================================
  def active_access?
    active? || past_due? || (canceled? && current_period_end.present? && current_period_end > Time.current)
  end

  def current_period_end
    return nil unless current_period_end_epoch
    Time.at(current_period_end_epoch).utc
  end
end
