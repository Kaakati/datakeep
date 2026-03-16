# frozen_string_literal: true

# AWS SES v2 delivery method for Action Mailer — production only.
# Skipped during asset precompilation (SECRET_KEY_BASE_DUMMY).
if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  Rails.application.config.after_initialize do
    require "aws-sdk-sesv2"

    Aws::Rails.add_action_mailer_delivery_method(
      :ses_v2,
      client: Aws::SESV2::Client.new(region: ENV.fetch("AWS_SES_REGION", "eu-south-1"))
    )

    ActionMailer::Base.delivery_method = :ses_v2
  end
end
