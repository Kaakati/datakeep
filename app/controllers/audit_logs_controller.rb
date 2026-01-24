# frozen_string_literal: true

class AuditLogsController < ApplicationController
  def index
    @audit_logs = AuditLog.by_user(current_user.id).recent

    # Filter by action if provided
    if params[:action_filter].present?
      @audit_logs = @audit_logs.by_action(params[:action_filter])
    end

    # Filter by resource type if provided
    if params[:resource_type].present?
      @audit_logs = @audit_logs.by_resource(params[:resource_type])
    end

    @audit_logs = @audit_logs.limit(100)
  end

  def show
    @audit_log = AuditLog.by_user(current_user.id).find(params[:id])
  end
end
