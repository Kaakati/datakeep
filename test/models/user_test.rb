require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.new(
      name: "Test User",
      email: "test@example.com",
      password: "password123"
    )
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should require name" do
    @user.name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:name], "can't be blank"
  end

  test "should require email" do
    @user.email = nil
    assert_not @user.valid?
    assert_includes @user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    @user.save!
    duplicate_user = User.new(
      name: "Another User",
      email: "test@example.com",
      password: "password456"
    )
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "should require valid email format" do
    invalid_emails = ["invalid", "invalid@", "@example.com", "test@.com"]
    invalid_emails.each do |email|
      @user.email = email
      assert_not @user.valid?, "#{email} should be invalid"
    end
  end

  test "should require password" do
    @user.password = nil
    assert_not @user.valid?
  end

  test "should authenticate with correct password" do
    @user.save!
    assert @user.authenticate("password123")
  end

  test "should not authenticate with incorrect password" do
    @user.save!
    assert_not @user.authenticate("wrongpassword")
  end

  test "log_action creates audit log" do
    @user.save!

    assert_difference "AuditLog.count", 1 do
      @user.log_action("test_action", details: { test: true })
    end

    audit_log = AuditLog.last
    assert_equal "test_action", audit_log.action
    assert_equal @user.id, audit_log.user_id
    assert_equal({ test: true }, audit_log.parsed_details)
  end
end
