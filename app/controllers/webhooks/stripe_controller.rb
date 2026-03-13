# frozen_string_literal: true

module Webhooks
  class StripeController < ActionController::API
    def create
      payload = request.body.read
      webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"]

      if webhook_secret.present?
        sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
        event = Stripe::Webhook.construct_event(payload, sig_header, webhook_secret)
      else
        data = JSON.parse(payload, symbolize_names: true)
        event = Stripe::Event.construct_from(data)
      end

      DataKeep::Stripe::WebhookHandler.new(event).process
      head :ok
    rescue Stripe::SignatureVerificationError
      head :bad_request
    rescue => e
      Rails.logger.error("Stripe webhook error: #{e.message}")
      head :ok # Return 200 to prevent Stripe retries for app errors
    end
  end
end
