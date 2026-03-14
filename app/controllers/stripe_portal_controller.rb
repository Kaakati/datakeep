# frozen_string_literal: true

class StripePortalController < ApplicationController
  # POST /stripe_portal — redirect to Stripe Customer Portal
  def create
    portal_url = DataKeep::Stripe::PortalSessionService.new(user: current_user).call
    redirect_to portal_url, allow_other_host: true
  rescue StandardError => e
    Rails.logger.error("Stripe Portal failed: #{e.message}")
    redirect_to billing_path, alert: "Unable to open billing portal. Please try again."
  end
end
