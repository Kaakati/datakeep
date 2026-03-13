# frozen_string_literal: true

class BillingController < ApplicationController
  def show
    @plan_limits = current_user.plan_limits
    @usage = current_user.resource_usage
    @quote = current_user.active_enterprise_quote
  end
end
