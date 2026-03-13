# frozen_string_literal: true

class StripeInvoiceJob < ApplicationJob
  queue_as :default

  retry_on Stripe::RateLimitError, Stripe::APIConnectionError, wait: 30.seconds, attempts: 3
  discard_on Stripe::InvalidRequestError

  def perform(enterprise_quote)
    DataKeep::Stripe::InvoiceService.new(enterprise_quote).create_and_send
  end
end
