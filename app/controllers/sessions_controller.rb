# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]
  verify_turnstile_request only: [ :create ]

  def new
    if logged_in?
      redirect_to current_user.admin? ? admin_root_path : root_path
      return
    end
  end

  def create
    if user = authenticate_user!(email: params[:email], password: params[:password])
      path = user.admin? ? admin_root_path : root_path
      redirect_to path, notice: "Welcome back, #{user.name}!"
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    log_out
    redirect_to login_path, notice: "You have been logged out."
  end
end
