# frozen_string_literal: true

class Coupon < ApplicationRecord
  enum :discount_type, { percent_off: 0, amount_off: 1 }
  enum :duration, { once: 0, repeating: 1, forever: 2 }

  validates :code, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[A-Z0-9_-]+\z/, message: "only uppercase letters, numbers, hyphens, underscores" }
  validates :discount_type, :discount_value, presence: true
  validates :discount_value, numericality: { greater_than: 0 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percent_off?
  validates :duration_in_months, presence: true, numericality: { greater_than: 0 }, if: :repeating?

  scope :active, -> { where(active: true) }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :available, -> { active.not_expired }
  scope :recent, -> { order(created_at: :desc) }

  before_validation :upcase_code

  def redeemable?
    active? && !expired? && !max_redemptions_reached?
  end

  def valid_for_plan?(plan_tier)
    applicable_plans == "all" || applicable_plan_list.include?(plan_tier.to_s)
  end

  def valid_for_checkout?(plan_tier)
    redeemable? && valid_for_plan?(plan_tier) && stripe_coupon_id.present?
  end

  def record_redemption!
    increment!(:redemptions_count)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def max_redemptions_reached?
    max_redemptions.present? && redemptions_count >= max_redemptions
  end

  def applicable_plan_list
    applicable_plans.to_s.split(",").map(&:strip)
  end

  def stripe_synced?
    stripe_coupon_id.present?
  end

  def discount_display
    if percent_off?
      "#{discount_value}% off"
    else
      "$#{"%.2f" % (discount_value / 100.0)} off"
    end
  end

  private

  def upcase_code
    self.code = code&.strip&.upcase
  end
end
