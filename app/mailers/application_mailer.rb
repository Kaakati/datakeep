# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: "DataKeep <no-reply@notifications.datakeep.ai>"
  layout "mailer"
end
