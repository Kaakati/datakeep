require "test_helper"

class BackupJobTest < ActiveSupport::TestCase
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
      username: "postgres",
      password: "secret"
    )

    @storage_backend = StorageBackends::LocalStorage.create!(
      user: @user,
      name: "Local Storage",
      config: { path: "/tmp/backups" }
    )

    @backup_job = BackupJob.new(
      user: @user,
      database_config: @database_config,
      storage_backend: @storage_backend,
      name: "Daily Backup",
      schedule_type: "daily",
      retention_days: 7
    )
  end

  test "should be valid with valid attributes" do
    assert @backup_job.valid?
  end

  test "should require name" do
    @backup_job.name = nil
    assert_not @backup_job.valid?
    assert_includes @backup_job.errors[:name], "can't be blank"
  end

  test "should require schedule_type" do
    @backup_job.schedule_type = nil
    assert_not @backup_job.valid?
    assert_includes @backup_job.errors[:schedule_type], "can't be blank"
  end

  test "should validate schedule_type inclusion" do
    invalid_types = ["invalid", "yearly", "secondly"]
    invalid_types.each do |type|
      @backup_job.schedule_type = type
      assert_not @backup_job.valid?, "#{type} should be invalid"
    end
  end

  test "should accept valid schedule types" do
    valid_types = BackupJob::SCHEDULE_TYPES
    valid_types.each do |type|
      @backup_job.schedule_type = type
      if type == "custom"
        @backup_job.cron_expression = "0 2 * * *"
      end
      assert @backup_job.valid?, "#{type} should be valid"
    end
  end

  test "should require cron_expression when schedule_type is custom" do
    @backup_job.schedule_type = "custom"
    @backup_job.cron_expression = nil
    assert_not @backup_job.valid?
    assert_includes @backup_job.errors[:cron_expression], "can't be blank"
  end

  test "should calculate next_run_at based on schedule_type" do
    @backup_job.save!
    assert_not_nil @backup_job.next_run_at
    assert @backup_job.next_run_at > Time.current
  end

  test "should calculate next_run_at for hourly schedule" do
    @backup_job.schedule_type = "hourly"
    @backup_job.save!
    assert @backup_job.next_run_at <= 1.hour.from_now
  end

  test "should calculate next_run_at for custom cron" do
    @backup_job.schedule_type = "custom"
    @backup_job.cron_expression = "0 2 * * *"
    @backup_job.save!
    assert_not_nil @backup_job.next_run_at
  end

  test "success_rate returns 0 when no backups" do
    @backup_job.save!
    assert_equal 0, @backup_job.success_rate
  end

  test "success_rate calculates correctly" do
    @backup_job.save!

    # Create 8 completed and 2 failed backups
    8.times do |i|
      Backup.create!(
        backup_job: @backup_job,
        storage_backend: @storage_backend,
        file_name: "backup_#{i}.sql",
        status: "completed"
      )
    end

    2.times do |i|
      Backup.create!(
        backup_job: @backup_job,
        storage_backend: @storage_backend,
        file_name: "backup_failed_#{i}.sql",
        status: "failed"
      )
    end

    assert_equal 80, @backup_job.success_rate
  end

  test "due? returns true when next_run_at is in the past" do
    @backup_job.save!
    @backup_job.update_column(:next_run_at, 1.minute.ago)
    assert @backup_job.due?
  end

  test "due? returns false when next_run_at is in the future" do
    @backup_job.save!
    assert_not @backup_job.due?
  end

  test "due? returns false when disabled" do
    @backup_job.enabled = false
    @backup_job.save!
    @backup_job.update_column(:next_run_at, 1.minute.ago)
    assert_not @backup_job.due?
  end
end
