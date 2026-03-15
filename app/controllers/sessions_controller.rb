# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]
  skip_email_verification only: [:destroy]
  # verify_turnstile_request only: [ :create ] # Temporarily disabled — widget not loading on production

  def new
    if logged_in?
      redirect_to current_user.admin? ? admin_root_path : dashboard_path
      return
    end
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user&.authenticate(params[:password])
      if user.otp_required?
        initiate_otp_flow(user)
      else
        log_in(user)
        path = user.admin? ? admin_root_path : dashboard_path
        redirect_to path, notice: "Welcome back, #{user.name}!"
      end
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to login_path, notice: "You have been logged out."
  end

  private

  def initiate_otp_flow(user)
    code = SecureRandom.random_number(10**6).to_s.rjust(6, "0")
    session[:otp_user_id] = user.id
    session[:otp_code] = code
    session[:otp_expires_at] = 10.minutes.from_now.to_i
    session[:otp_attempts] = 0
    UserMailer.login_otp(user, code).deliver_later
    redirect_to otp_verification_path, notice: "A verification code has been sent to your email."
  end
end
