# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def email_verification(user)
    @user = user
    @verification_url = confirm_email_verification_url(
      token: user.signed_id(purpose: :email_verification, expires_in: 24.hours)
    )
    mail(to: @user.email, subject: "Verify your email address — DataKeep")
  end

  def login_otp(user, otp_code)
    @user = user
    @otp_code = otp_code
    mail(to: @user.email, subject: "Your DataKeep login code: #{otp_code}")
  end
end
