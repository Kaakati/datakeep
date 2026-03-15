# frozen_string_literal: true

class EmailVerificationsController < ApplicationController
  skip_email_verification
  allow_unauthenticated_access only: [:update]

  # GET /verify_email — interstitial page
  def show
    redirect_to dashboard_path if current_user.email_verified?
  end

  # GET /verify_email/confirm?token=xxx — verify token
  def update
    user = User.find_signed(params[:token], purpose: :email_verification)
    if user
      user.verify_email!
      log_in(user) unless logged_in?
      redirect_to dashboard_path, notice: "Your email has been verified. Welcome to DataKeep!"
    else
      if logged_in?
        @expired = true
        render :show, status: :unprocessable_entity
      else
        redirect_to login_path, alert: "Verification link has expired. Please log in and request a new one."
      end
    end
  end

  # POST /verify_email/resend — resend email
  def create
    if current_user && !current_user.email_verified?
      current_user.send_verification_email
      redirect_to email_verification_path, notice: "Verification email sent! Check your inbox."
    else
      redirect_to dashboard_path
    end
  end
end
