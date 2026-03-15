# frozen_string_literal: true

class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]
  # verify_turnstile_request only: [ :create ] # Temporarily disabled — widget not loading on production

  def new
    redirect_to root_path if logged_in?
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      log_in(@user)
      redirect_to root_path, notice: "Welcome to DataKeep! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
