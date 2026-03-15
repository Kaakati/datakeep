# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy, :resend_verification ]

    def index
      @users = User.order(created_at: :desc)
      @users = @users.where("name ILIKE :q OR email ILIKE :q", q: "%#{params[:search]}%") if params[:search].present?
    end

    def show
      @database_configs = @user.database_configs
      @backup_jobs = @user.backup_jobs.includes(:database_config)
      @storage_backends = @user.storage_backends
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_user_path(@user), notice: "User created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      update_params = user_params
      update_params = update_params.except(:password, :password_confirmation) if update_params[:password].blank?
      if @user.update(update_params)
        redirect_to admin_user_path(@user), notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # POST /admin/users/:id/resend_verification
    def resend_verification
      if @user.email_verified?
        redirect_to admin_user_path(@user), notice: "#{@user.name}'s email is already verified."
      else
        @user.send_verification_email
        redirect_to admin_user_path(@user), notice: "Verification email sent to #{@user.email}."
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete yourself."
      else
        @user.destroy
        redirect_to admin_users_path, notice: "User deleted."
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :email, :role, :password, :password_confirmation)
    end
  end
end
