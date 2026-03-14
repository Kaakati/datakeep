# frozen_string_literal: true

module DataKeep
  module Stripe
    class PortalSessionService
      def initialize(user:)
        @user = user
      end

      def call
        customer_id = CustomerService.find_or_create(user: @user)

        session = ::Stripe::BillingPortal::Session.create(
          customer: customer_id,
          return_url: return_url
        )

        session.url
      end

      private

      def return_url
        "#{ENV.fetch('APP_BASE_URL', 'http://localhost:3000')}/billing"
      end
    end
  end
end
