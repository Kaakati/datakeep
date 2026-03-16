# frozen_string_literal: true

class StripeInvoiceJob
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 3

  sidekiq_retry_in do |_count, exception, _jobhash|
    case exception
    when Stripe::InvalidRequestError
      :discard
    when Stripe::RateLimitError, Stripe::APIConnectionError
      30
    end
  end

  def perform(enterprise_quote_id)
    quote = EnterpriseQuote.find(enterprise_quote_id)
    DataKeep::Stripe::InvoiceService.new(quote).create_and_send
  end
end
