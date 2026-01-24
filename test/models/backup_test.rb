require "test_helper"

class BackupTest < ActiveSupport::TestCase
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

    @backup = Backup.new(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "backup_20260122.sql.gz",
      status: "pending"
    )
  end

  test "should be valid with valid attributes" do
    assert @backup.valid?
  end

  test "should require file_name" do
    @backup.file_name = nil
    assert_not @backup.valid?
    assert_includes @backup.errors[:file_name], "can't be blank"
  end

  test "should require status" do
    @backup.status = nil
    assert_not @backup.valid?
    assert_includes @backup.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    valid_statuses = Backup::STATUSES
    valid_statuses.each do |status|
      @backup.status = status
      assert @backup.valid?, "#{status} should be valid"
    end

    @backup.status = "invalid_status"
    assert_not @backup.valid?
  end

  test "status query methods work correctly" do
    @backup.status = "pending"
    assert @backup.pending?

    @backup.status = "running"
    assert @backup.running?

    @backup.status = "completed"
    assert @backup.completed?

    @backup.status = "failed"
    assert @backup.failed?
  end

  test "duration returns nil without timestamps" do
    assert_nil @backup.duration
  end

  test "duration calculates correctly with timestamps" do
    @backup.started_at = Time.current - 120.seconds
    @backup.completed_at = Time.current

    assert_in_delta 120, @backup.duration, 1
  end

  test "formatted_duration returns N/A without duration" do
    assert_equal "N/A", @backup.formatted_duration
  end

  test "formatted_duration formats seconds correctly" do
    @backup.started_at = Time.current - 45.seconds
    @backup.completed_at = Time.current

    assert_match(/\d+(\.\d)?s/, @backup.formatted_duration)
  end

  test "formatted_duration formats minutes correctly" do
    @backup.started_at = Time.current - 5.minutes
    @backup.completed_at = Time.current

    assert_match(/\d+(\.\d)?m/, @backup.formatted_duration)
  end

  test "formatted_duration formats hours correctly" do
    @backup.started_at = Time.current - 2.hours
    @backup.completed_at = Time.current

    assert_match(/\d+(\.\d)?h/, @backup.formatted_duration)
  end

  test "formatted_file_size returns N/A without file_size" do
    assert_equal "N/A", @backup.formatted_file_size
  end

  test "formatted_file_size formats bytes correctly" do
    @backup.file_size = 500
    assert_equal "500 B", @backup.formatted_file_size
  end

  test "formatted_file_size formats KB correctly" do
    @backup.file_size = 5000
    assert_match(/\d+\.\d+ KB/, @backup.formatted_file_size)
  end

  test "formatted_file_size formats MB correctly" do
    @backup.file_size = 5_000_000
    assert_match(/\d+\.\d+ MB/, @backup.formatted_file_size)
  end

  test "formatted_file_size formats GB correctly" do
    @backup.file_size = 5_000_000_000
    assert_match(/\d+\.\d+ GB/, @backup.formatted_file_size)
  end

  test "start! updates status and started_at" do
    @backup.save!
    @backup.start!

    assert @backup.running?
    assert_not_nil @backup.started_at
  end

  test "complete! updates status and metadata" do
    @backup.save!
    @backup.start!
    @backup.complete!(
      file_path: "/tmp/backups/backup_20260122.sql.gz",
      file_size: 1024,
      checksum: "abc123"
    )

    assert @backup.completed?
    assert_equal "/tmp/backups/backup_20260122.sql.gz", @backup.file_path
    assert_equal 1024, @backup.file_size
    assert_equal "abc123", @backup.checksum
    assert_not_nil @backup.completed_at
  end

  test "fail! updates status and error message" do
    @backup.save!
    @backup.start!
    @backup.fail!("Connection refused")

    assert @backup.failed?
    assert_equal "Connection refused", @backup.error_message
    assert_not_nil @backup.completed_at
  end

  test "scopes filter by status" do
    @backup.save!
    running_backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "running_backup.sql.gz",
      status: "running"
    )

    assert_includes Backup.pending, @backup
    assert_includes Backup.running, running_backup
    assert_not_includes Backup.pending, running_backup
  end

  test "recent scope orders by created_at desc" do
    @backup.save!
    sleep 0.01
    newer_backup = Backup.create!(
      backup_job: @backup_job,
      storage_backend: @storage_backend,
      file_name: "newer_backup.sql.gz",
      status: "pending"
    )

    assert_equal newer_backup, Backup.recent.first
  end

  test "user delegation works" do
    @backup.save!
    assert_equal @user, @backup.user
  end

  test "display_name includes job name, date, and size" do
    @backup.save!
    @backup.update!(file_size: 1024)

    display = @backup.display_name
    assert_includes display, "Daily Backup"
    # The format is "1.0 KB" with decimal point
    assert_match(/1(\.\d+)? KB/, display)
  end

  test "encrypted? returns backup_job encryption setting" do
    @backup.save!
    @backup_job.update!(encryption: true)
    assert @backup.encrypted?

    @backup_job.update!(encryption: false)
    assert_not @backup.encrypted?
  end

  test "compressed? returns backup_job compression setting" do
    @backup.save!
    @backup_job.update!(compression: true)
    assert @backup.compressed?

    @backup_job.update!(compression: false)
    assert_not @backup.compressed?
  end
end
