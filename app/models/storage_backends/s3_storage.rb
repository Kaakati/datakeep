# frozen_string_literal: true

module StorageBackends
  class S3Storage < StorageBackend
    validates :encrypted_config, presence: true

    def bucket_name
      config[:bucket]
    end

    def region
      config[:region] || "us-east-1"
    end

    def prefix
      config[:prefix] || ""
    end

    def store(source_path, destination_name)
      key = build_key(destination_name)

      File.open(source_path, "rb") do |file|
        s3_client.put_object(
          bucket: bucket_name,
          key: key,
          body: file
        )
      end

      key
    end

    def retrieve(source_key, destination_path)
      key = source_key.start_with?(prefix) ? source_key : build_key(source_key)

      File.open(destination_path, "wb") do |file|
        s3_client.get_object(bucket: bucket_name, key: key) do |chunk|
          file.write(chunk)
        end
      end

      destination_path
    end

    def delete(key)
      full_key = key.start_with?(prefix) ? key : build_key(key)
      s3_client.delete_object(bucket: bucket_name, key: full_key)
      true
    rescue Aws::S3::Errors::NoSuchKey
      true
    end

    def exists?(key)
      full_key = key.start_with?(prefix) ? key : build_key(key)
      s3_client.head_object(bucket: bucket_name, key: full_key)
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    def test_connection
      s3_client.head_bucket(bucket: bucket_name)
      { success: true, message: "S3 bucket #{bucket_name} is accessible" }
    rescue Aws::S3::Errors::ServiceError => e
      { success: false, error: e.message }
    end

    def list_objects(prefix_filter: nil)
      full_prefix = prefix_filter ? build_key(prefix_filter) : prefix
      response = s3_client.list_objects_v2(bucket: bucket_name, prefix: full_prefix)
      response.contents.map do |obj|
        {
          key: obj.key,
          size: obj.size,
          last_modified: obj.last_modified
        }
      end
    end

    private

    def build_key(name)
      return name if prefix.blank?
      "#{prefix.chomp('/')}/#{name}"
    end

    def s3_client
      @s3_client ||= Aws::S3::Client.new(
        region: region,
        access_key_id: config[:access_key_id],
        secret_access_key: config[:secret_access_key],
        endpoint: config[:endpoint].presence
      )
    end
  end
end
