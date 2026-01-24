require "test_helper"

class DatabaseConfigTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    @database_config = DatabaseConfig.new(
      user: @user,
      name: "Production DB",
      host: "localhost",
      port: 5432,
      database_name: "myapp_production",
      username: "postgres",
      password: "secret123"
    )
  end

  test "should be valid with valid attributes" do
    assert @database_config.valid?
  end

  test "should require name" do
    @database_config.name = nil
    assert_not @database_config.valid?
    assert_includes @database_config.errors[:name], "can't be blank"
  end

  test "should require unique name per user" do
    @database_config.save!
    duplicate = DatabaseConfig.new(
      user: @user,
      name: "Production DB",
      host: "otherhost",
      port: 5432,
      database_name: "other_db",
      username: "postgres"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows same name for different users" do
    @database_config.save!

    other_user = User.create!(
      name: "Other User",
      email: "other#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    duplicate = DatabaseConfig.new(
      user: other_user,
      name: "Production DB",
      host: "localhost",
      port: 5432,
      database_name: "other_db",
      username: "postgres"
    )
    assert duplicate.valid?
  end

  test "should require host" do
    @database_config.host = nil
    assert_not @database_config.valid?
    assert_includes @database_config.errors[:host], "can't be blank"
  end

  test "should require port" do
    @database_config.port = nil
    assert_not @database_config.valid?
    assert_includes @database_config.errors[:port], "can't be blank"
  end

  test "should validate port is positive integer" do
    @database_config.port = -1
    assert_not @database_config.valid?

    @database_config.port = 0
    assert_not @database_config.valid?

    @database_config.port = 65536
    assert_not @database_config.valid?

    @database_config.port = 5432
    assert @database_config.valid?
  end

  test "should require database_name" do
    @database_config.database_name = nil
    assert_not @database_config.valid?
    assert_includes @database_config.errors[:database_name], "can't be blank"
  end

  test "should require username" do
    @database_config.username = nil
    assert_not @database_config.valid?
    assert_includes @database_config.errors[:username], "can't be blank"
  end

  test "should validate ssl_mode inclusion" do
    valid_modes = DatabaseConfig::SSL_MODES
    valid_modes.each do |mode|
      @database_config.ssl_mode = mode
      assert @database_config.valid?, "#{mode} should be valid"
    end

    @database_config.ssl_mode = "invalid_mode"
    assert_not @database_config.valid?
  end

  test "allows blank ssl_mode" do
    @database_config.ssl_mode = nil
    assert @database_config.valid?

    @database_config.ssl_mode = ""
    assert @database_config.valid?
  end

  test "connection_params returns hash with connection details" do
    @database_config.ssl_mode = "require"
    params = @database_config.connection_params

    assert_equal "localhost", params[:host]
    assert_equal 5432, params[:port]
    assert_equal "myapp_production", params[:dbname]
    assert_equal "postgres", params[:user]
    assert_equal "secret123", params[:password]
    assert_equal "require", params[:sslmode]
  end

  test "connection_params defaults ssl_mode to prefer" do
    @database_config.ssl_mode = nil
    params = @database_config.connection_params

    assert_equal "prefer", params[:sslmode]
  end

  test "connection_string masks password" do
    conn_string = @database_config.connection_string

    assert_includes conn_string, "localhost"
    assert_includes conn_string, "5432"
    assert_includes conn_string, "myapp_production"
    assert_includes conn_string, "***"
    assert_not_includes conn_string, "secret123"
  end

  test "healthy? returns true when health_status is healthy" do
    @database_config.health_status = "healthy"
    assert @database_config.healthy?
    assert_not @database_config.unhealthy?
  end

  test "unhealthy? returns true when health_status is unhealthy" do
    @database_config.health_status = "unhealthy"
    assert @database_config.unhealthy?
    assert_not @database_config.healthy?
  end

  test "scopes filter by health status" do
    @database_config.health_status = "healthy"
    @database_config.save!

    unhealthy_config = DatabaseConfig.create!(
      user: @user,
      name: "Unhealthy DB",
      host: "localhost",
      port: 5433,
      database_name: "unhealthy_db",
      username: "postgres",
      health_status: "unhealthy"
    )

    assert_includes DatabaseConfig.healthy, @database_config
    assert_not_includes DatabaseConfig.healthy, unhealthy_config

    assert_includes DatabaseConfig.unhealthy, unhealthy_config
    assert_not_includes DatabaseConfig.unhealthy, @database_config
  end
end
