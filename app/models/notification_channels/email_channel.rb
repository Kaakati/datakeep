# frozen_string_literal: true

module NotificationChannels
  class EmailChannel < NotificationChannel
    validates :encrypted_config, presence: true

    def to_address
      config[:to_address]
    end

    def from_address
      config[:from_address] || "noreply@database-ops.local"
    end

    def send_notification(event, backup = nil)
      BackupMailer.notification(
        to: to_address,
        from: from_address,
        subject: build_subject(event, backup),
        body: build_message(event, backup)
      ).deliver_later
      { success: true }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    def test_notification
      send_notification(:test)
    end

    private

    def build_subject(event, backup)
      db_name = backup&.database_name || "Database"
      case event.to_s
      when "success"
        "[Database-Ops] Backup completed: #{db_name}"
      when "failure"
        "[Database-Ops] Backup failed: #{db_name}"
      when "test"
        "[Database-Ops] Test notification"
      else
        "[Database-Ops] #{event}"
      end
    end
  end
end
