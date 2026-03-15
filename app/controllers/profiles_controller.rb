# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :set_user

  def show
  end

  def edit
  end

  def update
    if needs_password_verification? && !@user.authenticate(params[:user][:current_password].to_s)
      @user.errors.add(:current_password, "is incorrect")
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def enable_otp
    @user.update!(otp_required: true)
    redirect_to profile_path, notice: "Two-factor authentication has been enabled."
  end

  def disable_otp
    @user.update!(otp_required: false)
    redirect_to profile_path, notice: "Two-factor authentication has been disabled."
  end

  private

  def set_user
    @user = current_user
  end

  def profile_params
    permitted = [:name, :email]
    permitted += [:password, :password_confirmation] if params.dig(:user, :password).present?
    params.require(:user).permit(permitted)
  end

  def needs_password_verification?
    !@user.oauth_user? && params.dig(:user, :password).present?
  end
end
