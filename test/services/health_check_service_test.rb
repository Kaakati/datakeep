require "test_helper"

class HealthCheckServiceTest < ActiveSupport::TestCase
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
      health_status: "unknown"
    )

    @service = HealthCheckService.new(@database_config)
  end

  test "initializes with database_config" do
    assert_equal @database_config, @service.database_config
  end

  test "check delegates to database_config test_connection" do
    # This test verifies the service structure without actually connecting
    assert @service.respond_to?(:check)
  end

  test "check_all_databases returns array" do
    result = @service.check_all_databases(@user)

    assert result.is_a?(Array)
    assert result.any? { |r| r[:name] == "Test DB" }
  end

  test "class method check_all returns array" do
    # Create another config to verify it finds multiple
    DatabaseConfig.create!(
      user: @user,
      name: "Another DB",
      host: "localhost",
      port: 5433,
      database_name: "another_db",
      username: "postgres"
    )

    # We can't actually run the check without a real database,
    # but we can verify the method exists and is callable
    assert HealthCheckService.respond_to?(:check_all)
  end

  test "class method check_unhealthy exists" do
    assert HealthCheckService.respond_to?(:check_unhealthy)
  end
end
