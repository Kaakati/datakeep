# frozen_string_literal: true

# Kept for ActionMailer deliver_later compatibility.
# All custom jobs use Sidekiq::Job directly.
class ApplicationJob < ActiveJob::Base
end
