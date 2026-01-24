require "test_helper"

class EncryptionServiceTest < ActiveSupport::TestCase
  def setup
    @key = EncryptionService.generate_key
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  test "encrypts and decrypts data correctly" do
    original_data = "This is sensitive data that needs to be encrypted"
    encrypted = EncryptionService.encrypt(original_data, @key)

    assert encrypted.is_a?(Hash)
    assert encrypted[:iv].present?
    assert encrypted[:auth_tag].present?
    assert encrypted[:ciphertext].present?

    decrypted = EncryptionService.decrypt(encrypted, @key)
    assert_equal original_data, decrypted
  end

  test "encrypts file and produces encrypted output" do
    input_path = File.join(@temp_dir, "test_input.txt")
    output_path = File.join(@temp_dir, "test_output.enc")
    original_content = "This is the content of the backup file\n" * 100

    File.write(input_path, original_content)

    EncryptionService.encrypt_file(input_path, output_path, @key)

    assert File.exist?(output_path)
    encrypted_content = File.binread(output_path)
    assert_not_equal original_content, encrypted_content
  end

  test "decrypts file and restores original content" do
    input_path = File.join(@temp_dir, "test_input.txt")
    encrypted_path = File.join(@temp_dir, "test_output.enc")
    decrypted_path = File.join(@temp_dir, "test_decrypted.txt")
    original_content = "This is the content of the backup file\n" * 100

    File.write(input_path, original_content)

    EncryptionService.encrypt_file(input_path, encrypted_path, @key)
    EncryptionService.decrypt_file(encrypted_path, decrypted_path, @key)

    decrypted_content = File.read(decrypted_path)
    assert_equal original_content, decrypted_content
  end

  test "handles binary data correctly" do
    input_path = File.join(@temp_dir, "test_binary.bin")
    encrypted_path = File.join(@temp_dir, "test_binary.enc")
    decrypted_path = File.join(@temp_dir, "test_binary_decrypted.bin")
    original_content = SecureRandom.random_bytes(1024)

    File.binwrite(input_path, original_content)

    EncryptionService.encrypt_file(input_path, encrypted_path, @key)
    EncryptionService.decrypt_file(encrypted_path, decrypted_path, @key)

    decrypted_content = File.binread(decrypted_path)
    assert_equal original_content, decrypted_content
  end

  test "encrypt and decrypt are inverse operations" do
    test_strings = [
      "",
      "a",
      "Hello, World!",
      "Special chars: !@#$%^&*()",
      "Multi\nLine\nContent",
      "x" * 10_000
    ]

    test_strings.each do |str|
      encrypted = EncryptionService.encrypt(str, @key)
      decrypted = EncryptionService.decrypt(encrypted, @key)
      # Force UTF-8 encoding for comparison since decryption returns ASCII-8BIT
      assert_equal str, decrypted.force_encoding("UTF-8"), "Failed for string: #{str.truncate(50)}"
    end
  end

  test "handles unicode data correctly" do
    unicode_str = "Unicode: \u2603 \u2764 \u263A"
    encrypted = EncryptionService.encrypt(unicode_str, @key)
    decrypted = EncryptionService.decrypt(encrypted, @key)

    # Force UTF-8 encoding since OpenSSL returns ASCII-8BIT
    decrypted_utf8 = decrypted.force_encoding("UTF-8")
    assert_equal unicode_str, decrypted_utf8
  end

  test "different encryptions of same data produce different ciphertext" do
    data = "Same data encrypted twice"
    encrypted1 = EncryptionService.encrypt(data, @key)
    encrypted2 = EncryptionService.encrypt(data, @key)

    # Due to random IV, ciphertexts should differ
    assert_not_equal encrypted1[:ciphertext], encrypted2[:ciphertext]

    # But both should decrypt to the same value
    assert_equal data, EncryptionService.decrypt(encrypted1, @key)
    assert_equal data, EncryptionService.decrypt(encrypted2, @key)
  end

  test "raises error when decrypting with wrong key" do
    data = "Secret data"
    encrypted = EncryptionService.encrypt(data, @key)
    wrong_key = EncryptionService.generate_key

    assert_raises(EncryptionService::DecryptionError) do
      EncryptionService.decrypt(encrypted, wrong_key)
    end
  end

  test "generate_key produces 32-byte key" do
    key = EncryptionService.generate_key
    assert_equal 32, key.bytesize
  end

  test "derive_key produces consistent key with same password and salt" do
    password = "mysecretpassword"
    key1, salt = EncryptionService.derive_key(password)
    key2, _ = EncryptionService.derive_key(password, salt)

    assert_equal key1, key2
  end
end
