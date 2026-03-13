# frozen_string_literal: true

module Admin
  class PricingConfigsController < BaseController
    before_action :set_pricing_config, only: [ :edit, :update ]

    def index
      @pricing_configs = PricingConfig.order(:key)
    end

    def edit
    end

    def update
      if @pricing_config.update(pricing_config_params)
        Rails.cache.delete("pricing_config/#{@pricing_config.key}")
        redirect_to admin_pricing_configs_path, notice: "Pricing config updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_pricing_config
      @pricing_config = PricingConfig.find(params[:id])
    end

    def pricing_config_params
      permitted = params.require(:pricing_config).permit(:description, :value_json)
      if permitted[:value_json].present?
        permitted[:value] = JSON.parse(permitted[:value_json])
        permitted.delete(:value_json)
      end
      permitted
    end
  end
end
