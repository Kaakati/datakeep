# frozen_string_literal: true

class PricingConfig < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.get(key)
    find_by!(key: key).value
  end

  def self.cached_get(key)
    Rails.cache.fetch("pricing_config/#{key}", expires_in: 5.minutes) do
      get(key)
    end
  end
end
