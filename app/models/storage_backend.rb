# frozen_string_literal: true

class StorageBackend < ApplicationRecord
  belongs_to :user, optional: true
  has_many :backup_jobs, dependent: :restrict_with_error, foreign_key: :storage_backend_id
  has_many :backup_job_storage_backends, dependent: :restrict_with_error
  has_many :backups, dependent: :restrict_with_error

  encrypts :encrypted_config

  validates :name, presence: true
  validates :name, uniqueness: { scope: :user_id }, unless: :managed?
  validates :name, uniqueness: true, if: :managed?
  validates :type, presence: true
  validates :user, presence: true, unless: :managed?

  scope :default_storage, -> { where(is_default: true) }
  scope :managed, -> { where(managed: true) }
  scope :user_owned, -> { where(managed: false) }

  before_save :ensure_single_default

  def config
    return {} if encrypted_config.blank?
    JSON.parse(encrypted_config, symbolize_names: true)
  rescue JSON::ParserError
    {}
  end

  def config=(value)
    self.encrypted_config = value.is_a?(String) ? value : value.to_json
  end

  def store(file_path, destination_path)
    raise NotImplementedError, "Subclasses must implement #store"
  end

  def retrieve(source_path, destination_path)
    raise NotImplementedError, "Subclasses must implement #retrieve"
  end

  def delete(path)
    raise NotImplementedError, "Subclasses must implement #delete"
  end

  def exists?(path)
    raise NotImplementedError, "Subclasses must implement #exists?"
  end

  def test_connection
    raise NotImplementedError, "Subclasses must implement #test_connection"
  end

  def storage_type
    self.class.name.demodulize.underscore.gsub("_storage", "")
  end

  private

  def ensure_single_default
    return unless is_default? && is_default_changed?
    return unless user.present?

    user.storage_backends.where(is_default: true).where.not(id: id).update_all(is_default: false)
  end
end
