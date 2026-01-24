# frozen_string_literal: true

class EncryptionService
  ALGORITHM = "aes-256-gcm"
  KEY_LENGTH = 32
  IV_LENGTH = 12
  AUTH_TAG_LENGTH = 16
  CHUNK_SIZE = 1024 * 1024  # 1MB chunks

  class EncryptionError < StandardError; end
  class DecryptionError < StandardError; end

  class << self
    def generate_key
      SecureRandom.random_bytes(KEY_LENGTH)
    end

    def derive_key(password, salt = nil)
      salt ||= SecureRandom.random_bytes(16)
      key = OpenSSL::KDF.pbkdf2_hmac(
        password,
        salt: salt,
        iterations: 100_000,
        length: KEY_LENGTH,
        hash: "SHA256"
      )
      [ key, salt ]
    end

    def encrypt(plaintext, key)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt
      cipher.key = normalize_key(key)
      iv = cipher.random_iv

      ciphertext = cipher.update(plaintext) + cipher.final
      auth_tag = cipher.auth_tag

      # Format: IV + Auth Tag + Ciphertext (all Base64 encoded when stored)
      {
        iv: Base64.strict_encode64(iv),
        auth_tag: Base64.strict_encode64(auth_tag),
        ciphertext: Base64.strict_encode64(ciphertext)
      }
    end

    def decrypt(encrypted_data, key)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.decrypt
      cipher.key = normalize_key(key)
      cipher.iv = Base64.strict_decode64(encrypted_data[:iv])
      cipher.auth_tag = Base64.strict_decode64(encrypted_data[:auth_tag])

      cipher.update(Base64.strict_decode64(encrypted_data[:ciphertext])) + cipher.final
    rescue OpenSSL::Cipher::CipherError => e
      raise DecryptionError, "Failed to decrypt: #{e.message}"
    end

    def encrypt_file(input_path, output_path, key)
      cipher = OpenSSL::Cipher.new(ALGORITHM)
      cipher.encrypt
      cipher.key = normalize_key(key)
      iv = cipher.random_iv

      File.open(output_path, "wb") do |output|
        # Write IV at the beginning
        output.write(iv)

        File.open(input_path, "rb") do |input|
          while (chunk = input.read(CHUNK_SIZE))
            output.write(cipher.update(chunk))
          end
        end

        output.write(cipher.final)
        # Write auth tag at the end
        output.write(cipher.auth_tag)
      end

      output_path
    rescue OpenSSL::Cipher::CipherError => e
      File.delete(output_path) if File.exist?(output_path)
      raise EncryptionError, "Failed to encrypt file: #{e.message}"
    end

    def decrypt_file(input_path, output_path, key)
      File.open(input_path, "rb") do |input|
        # Read IV from beginning
        iv = input.read(IV_LENGTH)

        # Read the rest of the file
        encrypted_content = input.read

        # Extract auth tag from end
        auth_tag = encrypted_content[-AUTH_TAG_LENGTH..]
        ciphertext = encrypted_content[0...-AUTH_TAG_LENGTH]

        cipher = OpenSSL::Cipher.new(ALGORITHM)
        cipher.decrypt
        cipher.key = normalize_key(key)
        cipher.iv = iv
        cipher.auth_tag = auth_tag

        File.open(output_path, "wb") do |output|
          output.write(cipher.update(ciphertext) + cipher.final)
        end
      end

      output_path
    rescue OpenSSL::Cipher::CipherError => e
      File.delete(output_path) if File.exist?(output_path)
      raise DecryptionError, "Failed to decrypt file: #{e.message}"
    end

    private

    def normalize_key(key)
      if key.is_a?(String) && key.bytesize != KEY_LENGTH
        # If key is not the right size, derive it using PBKDF2
        derived_key, = derive_key(key, "database-ops-salt")
        derived_key
      else
        key
      end
    end
  end
end
