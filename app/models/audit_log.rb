# frozen_string_literal: true

class AuditLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true

  ACTIONS = %w[
    login logout
    create_database_config update_database_config delete_database_config test_database_config
    create_storage_backend update_storage_backend delete_storage_backend test_storage_backend
    create_backup_job update_backup_job delete_backup_job run_backup_job pause_backup_job resume_backup_job
    create_backup delete_backup restore_backup download_backup
    create_notification_channel update_notification_channel delete_notification_channel test_notification_channel
    upload_restore
    oauth_login
  ].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_resource, ->(type, id = nil) { where(resource_type: type).where(id ? { resource_id: id } : {}) }

  def self.log(action:, user: nil, resource: nil, details: nil, ip_address: nil)
    create!(
      action: action,
      user: user,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      details: details.is_a?(Hash) ? details.to_json : details,
      ip_address: ip_address
    )
  end

  def parsed_details
    return {} if details.blank?
    JSON.parse(details, symbolize_names: true)
  rescue JSON::ParserError
    { raw: details }
  end

  def resource
    return nil unless resource_type && resource_id
    resource_type.constantize.find_by(id: resource_id)
  rescue NameError
    nil
  end

  def human_action
    action.titleize.gsub("_", " ")
  end
end
