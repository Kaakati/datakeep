# frozen_string_literal: true

module Admin
  class BackupsController < BaseController
    def index
      @backups = Backup.includes(backup_job: [ :user, :database_config ]).order(created_at: :desc).limit(100)
    end

    def show
      @backup = Backup.find(params[:id])
    end
  end
end
