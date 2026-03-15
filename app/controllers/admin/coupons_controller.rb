# frozen_string_literal: true

module Admin
  class CouponsController < BaseController
    before_action :set_coupon, only: [:show, :edit, :update, :destroy, :toggle, :sync_to_stripe]

    def index
      @coupons = Coupon.recent
    end

    def show
    end

    def new
      @coupon = Coupon.new(active: true, discount_type: :percent_off, duration: :once)
    end

    def create
      @coupon = Coupon.new(coupon_params)

      if @coupon.save
        result = DataKeep::Stripe::CouponSyncService.new(@coupon).call
        if result[:success]
          redirect_to admin_coupon_path(@coupon), notice: "Coupon created and synced to Stripe."
        else
          redirect_to admin_coupon_path(@coupon), notice: "Coupon created but Stripe sync failed: #{result[:error]}"
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @coupon.update(coupon_params)
        redirect_to admin_coupon_path(@coupon), notice: "Coupon updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @coupon.redemptions_count > 0
        redirect_to admin_coupons_path,
          alert: "Cannot delete a coupon with #{@coupon.redemptions_count} redemption(s). Deactivate it instead."
        return
      end

      @coupon.destroy
      redirect_to admin_coupons_path, notice: "Coupon deleted."
    end

    # PATCH /admin/coupons/:id/toggle
    def toggle
      @coupon.update!(active: !@coupon.active)
      status = @coupon.active? ? "activated" : "deactivated"
      redirect_to admin_coupons_path, notice: "Coupon #{@coupon.code} #{status}."
    end

    # POST /admin/coupons/:id/sync_to_stripe
    def sync_to_stripe
      result = DataKeep::Stripe::CouponSyncService.new(@coupon).call

      if result[:success]
        redirect_to admin_coupon_path(@coupon), notice: "Synced to Stripe: #{result[:stripe_coupon_id]}"
      else
        redirect_to admin_coupon_path(@coupon), alert: "Stripe sync failed: #{result[:error]}"
      end
    end

    private

    def set_coupon
      @coupon = Coupon.find(params[:id])
    end

    def coupon_params
      params.require(:coupon).permit(
        :code, :discount_type, :discount_value, :currency,
        :duration, :duration_in_months, :max_redemptions,
        :expires_at, :applicable_plans, :active
      )
    end
  end
end
