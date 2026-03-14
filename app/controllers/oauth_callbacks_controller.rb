# frozen_string_literal: true

class OauthCallbacksController < ApplicationController
  allow_unauthenticated_access only: [:google_oauth2, :failure]

  def google_oauth2
    user = User.find_or_create_from_oauth(auth_hash)

    log_in(user)

    AuditLog.log(
      action: "oauth_login",
      user: user,
      details: { provider: "google_oauth2" },
      ip_address: request.remote_ip
    )

    redirect_to user.admin? ? admin_root_path : root_path,
                notice: "Signed in with Google."
  end

  def failure
    redirect_to login_path, alert: "Google sign-in failed: #{params[:message].to_s.humanize}"
  end

  private

  def auth_hash
    request.env["omniauth.auth"]
  end
end
