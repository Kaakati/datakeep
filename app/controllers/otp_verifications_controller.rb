# frozen_string_literal: true

class OtpVerificationsController < ApplicationController
  allow_unauthenticated_access

  before_action :require_otp_session

  # GET /otp_verify — show OTP entry form
  def show
    @email = otp_user&.email
  end

  # POST /otp_verify — verify the OTP code
  def create
    if session[:otp_expires_at].to_i < Time.current.to_i
      reset_otp_session
      redirect_to login_path, alert: "Your verification code has expired. Please log in again."
      return
    end

    attempts = session[:otp_attempts] || 0

    if attempts >= 5
      reset_otp_session
      redirect_to login_path, alert: "Too many failed attempts. Please log in again."
      return
    end

    submitted_code = params[:otp_code].to_s.strip

    if ActiveSupport::SecurityUtils.secure_compare(submitted_code, session[:otp_code].to_s)
      user = otp_user
      reset_otp_session
      log_in(user)
      redirect_to user.admin? ? admin_root_path : dashboard_path, notice: "Welcome back, #{user.name}!"
    else
      session[:otp_attempts] = attempts + 1
      flash.now[:alert] = "Invalid verification code. Please try again."
      @email = otp_user&.email
      render :show, status: :unprocessable_entity
    end
  end

  # POST /otp_verify/resend — resend OTP email
  def resend
    user = otp_user
    if user
      code = generate_otp_code
      session[:otp_code] = code
      session[:otp_expires_at] = 10.minutes.from_now.to_i
      session[:otp_attempts] = 0
      UserMailer.login_otp(user, code).deliver_later
      redirect_to otp_verification_path, notice: "A new verification code has been sent to your email."
    else
      redirect_to login_path, alert: "Session expired. Please log in again."
    end
  end

  private

  def require_otp_session
    unless session[:otp_user_id].present?
      redirect_to login_path, alert: "Please log in first."
    end
  end

  def otp_user
    @otp_user ||= User.find_by(id: session[:otp_user_id])
  end

  def reset_otp_session
    session.delete(:otp_user_id)
    session.delete(:otp_code)
    session.delete(:otp_expires_at)
    session.delete(:otp_attempts)
  end

  def generate_otp_code
    SecureRandom.random_number(10**6).to_s.rjust(6, "0")
  end
end
