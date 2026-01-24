# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    if user = authenticate_user!(email: params[:email], password: params[:password])
      redirect_to root_path, notice: "Welcome back, #{user.name}!"
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
