# frozen_string_literal: true

class EnterpriseQuote < ApplicationRecord
  belongs_to :admin_user, class_name: "User"
  belongs_to :user

  enum :status, { draft: 0, sent: 1, paid: 2, cancelled: 3, expired: 4 }

  validates :quote_params, presence: true
  validates :line_items_snapshot, presence: true
  validates :total_monthly_cents, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }

  def calculator_result
    DataKeep::EnterpriseQuoteCalculator::Result.new(**line_items_snapshot.deep_symbolize_keys.except(:line_items).merge(
      line_items: line_items_snapshot["line_items"].map do |item|
        DataKeep::EnterpriseQuoteCalculator::LineItem.new(**item.symbolize_keys)
      end
    ))
  end
end
