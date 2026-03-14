# frozen_string_literal: true

module Admin
  class SubscriptionPlansController < BaseController
    before_action :set_plan, only: [:show, :edit, :update, :destroy, :sync_to_stripe, :toggle]

    # GET /admin/subscription_plans
    def index
      @plans = SubscriptionPlan.sorted
    end

    # GET /admin/subscription_plans/:id
    def show
    end

    # GET /admin/subscription_plans/new
    def new
      @plan = SubscriptionPlan.new
    end

    # POST /admin/subscription_plans
    def create
      @plan = SubscriptionPlan.new(plan_params)

      if @plan.save
        redirect_to admin_subscription_plan_path(@plan), notice: "Subscription plan created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/subscription_plans/:id/edit
    def edit
    end

    # PATCH /admin/subscription_plans/:id
    def update
      if @plan.update(plan_params)
        redirect_to admin_subscription_plan_path(@plan), notice: "Subscription plan updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/subscription_plans/:id
    def destroy
      active_subscriptions = Subscription.where(plan_tier: @plan.tier_key).where.not(status: :canceled).count
      if active_subscriptions > 0
        redirect_to admin_subscription_plans_path,
          alert: "Cannot delete plan with #{active_subscriptions} active subscription(s). Disable it instead."
        return
      end

      @plan.destroy
      redirect_to admin_subscription_plans_path, notice: "Subscription plan deleted."
    end

    # POST /admin/subscription_plans/:id/sync_to_stripe
    def sync_to_stripe
      result = DataKeep::Stripe::PlanSyncService.new(@plan).call

      if result[:success]
        redirect_to admin_subscription_plan_path(@plan),
          notice: "Synced to Stripe. Product: #{result[:product_id]}"
      else
        redirect_to admin_subscription_plan_path(@plan),
          alert: "Stripe sync failed: #{result[:error]}"
      end
    end

    # PATCH /admin/subscription_plans/:id/toggle
    def toggle
      @plan.update!(enabled: !@plan.enabled)
      status = @plan.enabled? ? "enabled" : "disabled"
      redirect_to admin_subscription_plans_path, notice: "#{@plan.name} plan #{status}."
    end

    # POST /admin/subscription_plans/seed
    def seed
      seeded = 0
      PlanTierLimits::TIER_DEFINITIONS.each_with_index do |(tier_key, tier), idx|
        next if tier_key == :free
        next if SubscriptionPlan.exists?(tier_key: tier_key.to_s)

        SubscriptionPlan.create!(
          tier_key: tier_key.to_s,
          name: tier[:label],
          monthly_price_cents: tier[:monthly_price_cents],
          annual_price_cents: tier[:annual_price_cents],
          sort_order: idx,
          enabled: true,
          limits: {}
        )
        seeded += 1
      end

      redirect_to admin_subscription_plans_path,
        notice: "Seeded #{seeded} plan(s) from built-in defaults."
    end

    private

    def set_plan
      @plan = SubscriptionPlan.find(params[:id])
    end

    def plan_params
      params.require(:subscription_plan).permit(
        :tier_key, :name, :monthly_price_cents, :annual_price_cents,
        :enabled, :sort_order, :limits_json
      ).tap do |p|
        if p[:limits_json].present?
          p[:limits] = JSON.parse(p[:limits_json])
          p.delete(:limits_json)
        end
      end
    end
  end
end
