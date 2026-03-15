# frozen_string_literal: true

class SubscriptionsController < ApplicationController
  # POST /subscription — initiate Stripe Checkout for new subscription
  def create
    plan_tier = params[:plan_tier]
    billing_interval = params[:billing_interval] || "monthly"

    unless %w[starter professional business].include?(plan_tier)
      redirect_to billing_path, alert: "Invalid plan selected."
      return
    end

    checkout_url = DataKeep::Stripe::CheckoutService.new(
      user: current_user,
      plan_tier: plan_tier,
      billing_interval: billing_interval,
      coupon_code: params[:coupon_code].presence&.strip&.upcase
    ).call

    redirect_to checkout_url, allow_other_host: true
  rescue DataKeep::Stripe::CheckoutService::CouponError => e
    redirect_to billing_path, alert: e.message
  rescue StandardError => e
    Rails.logger.error("Checkout failed: #{e.message}")
    redirect_to billing_path, alert: "Unable to start checkout. Please try again."
  end

  # PATCH /subscription — upgrade or downgrade existing subscription
  def update
    result = DataKeep::Stripe::SubscriptionChangeService.new(
      user: current_user,
      new_plan_tier: params[:plan_tier],
      new_billing_interval: params[:billing_interval]
    ).call

    if result[:success]
      redirect_to billing_path, notice: "Your plan has been updated."
    else
      redirect_to billing_path, alert: result[:error]
    end
  end

  # DELETE /subscription — cancel at period end
  def destroy
    result = DataKeep::Stripe::CancelSubscriptionService.new(user: current_user).call

    if result[:success]
      redirect_to billing_path, notice: "Your subscription will be canceled at the end of the billing period."
    else
      redirect_to billing_path, alert: result[:error]
    end
  end
end
