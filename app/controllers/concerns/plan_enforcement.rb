# frozen_string_literal: true

module PlanEnforcement
  extend ActiveSupport::Concern

  RESOURCE_LABELS = {
    database_config: "databases",
    backup_job: "backup jobs",
    storage_backend: "storage backends",
    notification_channel: "notification channels"
  }.freeze

  class_methods do
    def enforce_plan_limit(resource_type, **options)
      before_action(**options) do
        enforce_plan_limit_for(resource_type)
      end
    end
  end

  private

  def enforce_plan_limit_for(resource_type)
    return if current_user.admin?
    return if current_user.can_create?(resource_type)

    limit = current_user.plan_limits[:"max_#{resource_type}s"]
    label = RESOURCE_LABELS[resource_type] || resource_type.to_s.humanize.pluralize.downcase

    flash[:alert] = "You've reached your plan's limit of #{limit} #{label}. " \
                    "Upgrade your plan to add more."

    redirect_to billing_path
  end
end
