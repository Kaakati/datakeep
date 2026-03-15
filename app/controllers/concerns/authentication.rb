# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    before_action :require_email_verification
    helper_method :current_user, :logged_in?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
      skip_before_action :require_email_verification, **options
    end

    def skip_email_verification(**options)
      skip_before_action :require_email_verification, **options
    end
  end

  private

  def require_authentication
    redirect_to login_path, alert: "Please log in to continue." unless logged_in?
  end

  def require_email_verification
    return unless logged_in?
    return if current_user.email_verified?
    return if current_user.admin?
    redirect_to email_verification_path
  end

  def require_admin
    redirect_to dashboard_path, alert: "Not authorized." unless current_user&.admin?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def log_in(user)
    reset_session
    session[:user_id] = user.id

    AuditLog.log(
      action: "login",
      user: user,
      ip_address: request.remote_ip
    )
  end

  def log_out
    if current_user
      AuditLog.log(
        action: "logout",
        user: current_user,
        ip_address: request.remote_ip
      )
    end

    reset_session
    @current_user = nil
  end

  def authenticate_user!(email:, password:)
    user = User.find_by(email: email.to_s.downcase.strip)

    if user&.authenticate(password)
      log_in(user)
      user
    else
      nil
    end
  end
end
