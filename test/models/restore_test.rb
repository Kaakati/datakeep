require "test_helper"

class RestoreTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test#{SecureRandom.hex(4)}@example.com",
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
      config: { path: "/tmp/backups" }
    )

    @backup_job = BackupJob.create!(
      user: @user,
      database_config: @database_config,
      storage_backend: @storage_backend,
      name: "Daily Backup",
      schedule_type: "daily",
      retention_days: 7
    )

    @backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "backup_20260122.sql.gz",
      status: "completed"
    )

    @restore = Restore.new(
      user: @user,
      database_config: @database_config,
      backup: @backup
    )
  end

  test "should be valid with valid attributes" do
    assert @restore.valid?
  end

  test "should require database_config" do
    @restore.database_config = nil
    assert_not @restore.valid?
    assert_includes @restore.errors[:database_config_id], "can't be blank"
  end

  test "backup is optional" do
    @restore.backup = nil
    @restore.file_path = "/tmp/uploaded_backup.sql"
    assert @restore.valid?
  end

  test "status defaults to pending" do
    assert_equal "pending", @restore.status
  end

  test "status enum works correctly" do
    @restore.status = :pending
    assert @restore.pending?

    @restore.status = :running
    assert @restore.running?

    @restore.status = :completed
    assert @restore.completed?

    @restore.status = :failed
    assert @restore.failed?
  end

  test "duration returns nil without timestamps" do
    assert_nil @restore.duration
  end

  test "duration calculates correctly with timestamps" do
    @restore.started_at = Time.current - 120.seconds
    @restore.completed_at = Time.current

    assert_in_delta 120, @restore.duration, 1
  end

  test "formatted_duration returns dash without duration" do
    assert_equal "-", @restore.formatted_duration
  end

  test "formatted_duration formats seconds correctly" do
    @restore.started_at = Time.current - 45.seconds
    @restore.completed_at = Time.current

    assert_match(/\d+s/, @restore.formatted_duration)
  end

  test "formatted_duration formats minutes correctly" do
    @restore.started_at = Time.current - 5.minutes
    @restore.completed_at = Time.current

    assert_match(/\d+m/, @restore.formatted_duration)
  end

  test "formatted_duration formats hours correctly" do
    @restore.started_at = Time.current - 2.hours - 30.minutes
    @restore.completed_at = Time.current

    result = @restore.formatted_duration
    assert_match(/\d+h \d+m/, result)
  end

  test "recent scope orders by created_at desc" do
    @restore.save!
    sleep 0.01
    newer_restore = Restore.create!(
      user: @user,
      database_config: @database_config,
      backup: @backup
    )

    assert_equal newer_restore, Restore.recent.first
  end
end
