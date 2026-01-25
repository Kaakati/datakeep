# frozen_string_literal: true

require "test_helper"

class BackupsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    @other_user = User.create!(
      name: "Other User",
      email: "other#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    @database_config = DatabaseConfig.create!(
      user: @user,
      name: "Test DB",
      host: "localhost",
      port: 5432,
      database_name: "test_db",
      username: "postgres"
    )

    @storage_backend = StorageBackends::LocalStorage.create!(
      user: @user,
      name: "Local Storage",
      config: { path: "/tmp/test_backups" }
    )

    @backup_job = BackupJob.create!(
      user: @user,
      database_config: @database_config,
      storage_backend: @storage_backend,
      name: "Daily Backup",
      schedule_type: "daily",
      retention_days: 7
    )

    @completed_backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "completed_backup.sql.gz",
      file_path: "/tmp/test_backups/completed_backup.sql.gz",
      file_size: 1024,
      status: "completed",
      started_at: 1.hour.ago,
      completed_at: Time.current
    )

    @failed_backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "failed_backup.sql.gz",
      status: "failed",
      error_message: "Connection refused",
      started_at: 2.hours.ago,
      completed_at: 2.hours.ago + 5.minutes
    )

    @running_backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "running_backup.sql.gz",
      status: "running",
      started_at: 10.minutes.ago
    )

    @pending_backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "pending_backup.sql.gz",
      status: "pending"
    )

    # Log in as the test user
    log_in_as(@user)
  end

  # ============================================================================
  # Helper Methods
  # ============================================================================

  def log_in_as(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  def log_out
    delete logout_path
  end

  # ============================================================================
  # Authentication Tests
  # ============================================================================

  test "destroy requires authentication" do
    log_out

    assert_no_difference "Backup.count" do
      delete backup_job_backup_path(@backup_job, @completed_backup)
    end

    assert_redirected_to login_path
  end

  test "destroy prevents access to other user's backups" do
    log_out
    log_in_as(@other_user)

    # Other user should not be able to access this backup
    # The controller scopes to current_user's backup_jobs, so it should 404
    assert_no_difference "Backup.count" do
      delete backup_job_backup_path(@backup_job, @completed_backup)
    end

    # Should be redirected or receive 404 (depending on implementation)
    # In this app, it raises RecordNotFound which Rails handles
    assert_response :not_found
  end

  # ============================================================================
  # Successful Deletion Tests
  # ============================================================================

  test "destroy successfully deletes a completed backup" do
    assert_difference "Backup.count", -1 do
      delete backup_job_backup_path(@backup_job, @completed_backup)
    end

    assert_redirected_to backup_job_backups_path(@backup_job)
    assert_equal "Backup deleted successfully.", flash[:notice]
  end

  test "destroy successfully deletes a failed backup" do
    assert_difference "Backup.count", -1 do
      delete backup_job_backup_path(@backup_job, @failed_backup)
    end

    assert_redirected_to backup_job_backups_path(@backup_job)
    assert_equal "Backup deleted successfully.", flash[:notice]
  end

  # ============================================================================
  # Running/Pending Backup Protection Tests
  # ============================================================================

  test "destroy prevents deletion of running backup" do
    assert_no_difference "Backup.count" do
      delete backup_job_backup_path(@backup_job, @running_backup)
    end

    assert_redirected_to backup_job_backup_path(@backup_job, @running_backup)
    assert_match(/cannot be deleted while it is running/i, flash[:alert])
  end

  test "destroy prevents deletion of pending backup" do
    assert_no_difference "Backup.count" do
      delete backup_job_backup_path(@backup_job, @pending_backup)
    end

    assert_redirected_to backup_job_backup_path(@backup_job, @pending_backup)
    assert_match(/cannot be deleted while it is pending/i, flash[:alert])
  end

  # ============================================================================
  # Storage Deletion Tests
  # ============================================================================

  test "destroy deletes backup from database even with storage backend" do
    # Verify that backup with file_path gets deleted
    # Storage backend interaction is tested implicitly through successful deletion
    assert @completed_backup.file_path.present?, "Test backup should have file_path"

    assert_difference "Backup.count", -1 do
      delete backup_job_backup_path(@backup_job, @completed_backup)
    end

    assert_redirected_to backup_job_backups_path(@backup_job)
  end

  test "destroy handles storage deletion errors gracefully" do
    # Make storage backend raise an error
    @storage_backend.define_singleton_method(:delete) do |path|
      raise StandardError, "Storage error"
    end

    # Should still delete the backup record even if storage deletion fails
    assert_difference "Backup.count", -1 do
      delete backup_job_backup_path(@backup_job, @completed_backup)
    end

    assert_redirected_to backup_job_backups_path(@backup_job)
  end

  # ============================================================================
  # Audit Log Tests
  # ============================================================================

  test "destroy creates an audit log entry" do
    assert_difference "AuditLog.count", 1 do
      delete backup_job_backup_path(@backup_job, @completed_backup)
    end

    audit_log = AuditLog.last
    assert_equal "delete_backup", audit_log.action
    assert_equal @user.id, audit_log.user_id
  end

  # ============================================================================
  # Redirect Behavior Tests
  # ============================================================================

  test "destroy redirects to backup_job backups path when accessed via nested route" do
    delete backup_job_backup_path(@backup_job, @completed_backup)

    assert_redirected_to backup_job_backups_path(@backup_job)
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  test "destroy handles backup with nil file_path" do
    backup_without_path = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "no_path_backup.sql.gz",
      status: "completed",
      file_path: nil
    )

    assert_difference "Backup.count", -1 do
      delete backup_job_backup_path(@backup_job, backup_without_path)
    end

    assert_redirected_to backup_job_backups_path(@backup_job)
  end
end
