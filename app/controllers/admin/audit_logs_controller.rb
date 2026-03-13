# frozen_string_literal: true

module Admin
  class AuditLogsController < BaseController
    def index
      @audit_logs = AuditLog.includes(:user).order(created_at: :desc)
      @audit_logs = @audit_logs.where("action ILIKE :q OR resource_type ILIKE :q", q: "%#{params[:search]}%") if params[:search].present?
      @audit_logs = @audit_logs.limit(100)
    end

    def show
      @audit_log = AuditLog.find(params[:id])
    end
  end
end
