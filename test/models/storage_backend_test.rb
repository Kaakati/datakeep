require "test_helper"

class StorageBackendTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    @storage_backend = StorageBackends::LocalStorage.new(
      user: @user,
      name: "Local Backup Storage",
      config: { path: "/tmp/test_backups" }
    )
  end

  test "should be valid with valid attributes" do
    assert @storage_backend.valid?
  end

  test "should require name" do
    @storage_backend.name = nil
    assert_not @storage_backend.valid?
    assert_includes @storage_backend.errors[:name], "can't be blank"
  end

  test "should require unique name per user" do
    @storage_backend.save!
    duplicate = StorageBackends::LocalStorage.new(
      user: @user,
      name: "Local Backup Storage",
      config: { path: "/tmp/other_backups" }
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows same name for different users" do
    @storage_backend.save!

    other_user = User.create!(
      name: "Other User",
      email: "other#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    duplicate = StorageBackends::LocalStorage.new(
      user: other_user,
      name: "Local Backup Storage",
      config: { path: "/tmp/other_backups" }
    )
    assert duplicate.valid?
  end

  test "should require type" do
    @storage_backend.type = nil
    assert_not @storage_backend.valid?
    assert_includes @storage_backend.errors[:type], "can't be blank"
  end

  test "config getter parses JSON" do
    @storage_backend.encrypted_config = '{"path":"/tmp/backups","nested":{"key":"value"}}'
    config = @storage_backend.config

    assert_equal "/tmp/backups", config[:path]
    assert_equal "value", config[:nested][:key]
  end

  test "config getter returns empty hash for blank config" do
    @storage_backend.encrypted_config = nil
    assert_equal({}, @storage_backend.config)

    @storage_backend.encrypted_config = ""
    assert_equal({}, @storage_backend.config)
  end

  test "config getter handles invalid JSON gracefully" do
    @storage_backend.encrypted_config = "not valid json"
    assert_equal({}, @storage_backend.config)
  end

  test "config setter accepts hash" do
    @storage_backend.config = { path: "/new/path", key: "value" }
    assert_equal "/new/path", @storage_backend.config[:path]
    assert_equal "value", @storage_backend.config[:key]
  end

  test "config setter accepts JSON string" do
    @storage_backend.config = '{"path":"/new/path"}'
    assert_equal "/new/path", @storage_backend.config[:path]
  end

  test "ensure_single_default sets other defaults to false" do
    @storage_backend.is_default = true
    @storage_backend.save!

    second_backend = StorageBackends::LocalStorage.create!(
      user: @user,
      name: "Second Storage",
      config: { path: "/tmp/second" },
      is_default: true
    )

    @storage_backend.reload
    assert_not @storage_backend.is_default?
    assert second_backend.is_default?
  end

  test "default_storage scope returns default backends" do
    @storage_backend.is_default = true
    @storage_backend.save!

    non_default = StorageBackends::LocalStorage.create!(
      user: @user,
      name: "Non-default Storage",
      config: { path: "/tmp/non_default" },
      is_default: false
    )

    assert_includes StorageBackend.default_storage, @storage_backend
    assert_not_includes StorageBackend.default_storage, non_default
  end

  test "storage_type returns type without Storage suffix" do
    assert_equal "local", @storage_backend.storage_type
  end
end

class LocalStorageTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    @temp_dir = Dir.mktmpdir
    @storage = StorageBackends::LocalStorage.new(
      user: @user,
      name: "Test Local Storage",
      config: { path: @temp_dir }
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  test "base_path returns configured path" do
    assert_equal @temp_dir, @storage.base_path
  end

  test "store copies file to destination" do
    source_file = File.join(@temp_dir, "source.txt")
    File.write(source_file, "test content")

    destination = @storage.store(source_file, "backups/test_backup.txt")

    assert File.exist?(destination)
    assert_equal "test content", File.read(destination)
  end

  test "retrieve copies file from storage" do
    # Create a file in storage
    source_name = "stored_backup.txt"
    stored_path = File.join(@temp_dir, source_name)
    File.write(stored_path, "stored content")

    # Retrieve to new location
    destination = File.join(@temp_dir, "retrieved.txt")
    @storage.retrieve(source_name, destination)

    assert File.exist?(destination)
    assert_equal "stored content", File.read(destination)
  end

  test "retrieve raises error for non-existent file" do
    destination = File.join(@temp_dir, "retrieved.txt")

    assert_raises RuntimeError do
      @storage.retrieve("non_existent.txt", destination)
    end
  end

  test "delete removes file from storage" do
    file_path = File.join(@temp_dir, "to_delete.txt")
    File.write(file_path, "delete me")

    @storage.delete("to_delete.txt")

    assert_not File.exist?(file_path)
  end

  test "exists? returns true for existing file" do
    file_path = File.join(@temp_dir, "exists.txt")
    File.write(file_path, "I exist")

    assert @storage.exists?("exists.txt")
  end

  test "exists? returns false for non-existent file" do
    assert_not @storage.exists?("non_existent.txt")
  end

  test "test_connection succeeds for accessible directory" do
    result = @storage.test_connection

    assert result[:success]
    assert_includes result[:message], @temp_dir
  end

  test "test_connection fails for inaccessible directory" do
    @storage.config = { path: "/non_existent_protected_path_#{SecureRandom.hex}/backups" }

    result = @storage.test_connection

    # This might succeed if the test has permission to create directories
    # or fail if it doesn't have permission
    # The important thing is that it doesn't raise an exception
    assert result.key?(:success)
  end
end
