# frozen_string_literal: true

class BackupJobNotificationChannel < ApplicationRecord
  belongs_to :backup_job
  belongs_to :notification_channel

  validates :backup_job_id, uniqueness: { scope: :notification_channel_id }
end
