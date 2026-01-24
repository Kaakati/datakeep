# frozen_string_literal: true

module StorageBackends
  class LocalStorage < StorageBackend
    validates :encrypted_config, presence: true

    def base_path
      config[:path] || Rails.root.join("storage", "backups").to_s
    end

    def store(source_path, destination_name)
      ensure_directory_exists
      destination = File.join(base_path, destination_name)

      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source_path, destination)

      destination
    end

    def retrieve(source_name, destination_path)
      # Handle both full paths and relative paths
      source = source_name.start_with?(base_path) ? source_name : File.join(base_path, source_name)
      raise "File not found: #{source}" unless File.exist?(source)

      FileUtils.cp(source, destination_path)
      destination_path
    end

    def delete(path)
      full_path = path.start_with?(base_path) ? path : File.join(base_path, path)
      FileUtils.rm_f(full_path)
      true
    end

    def exists?(path)
      full_path = path.start_with?(base_path) ? path : File.join(base_path, path)
      File.exist?(full_path)
    end

    def test_connection
      ensure_directory_exists
      test_file = File.join(base_path, ".test_#{Time.current.to_i}")

      File.write(test_file, "test")
      File.delete(test_file)

      { success: true, message: "Local storage accessible at #{base_path}" }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def available_space
      stat = Sys::Filesystem.stat(base_path) rescue nil
      return nil unless stat

      stat.block_size * stat.blocks_available
    end

    private

    def ensure_directory_exists
      FileUtils.mkdir_p(base_path)
    end
  end
end
