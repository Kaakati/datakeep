# frozen_string_literal: true

module DataKeep
  module Stripe
    class CustomerService
      def self.find_or_create(user:)
        new(user).find_or_create
      end

      def initialize(user)
        @user = user
      end

      def find_or_create
        return @user.stripe_customer_id if @user.stripe_customer_id.present?

        # Search Stripe for existing customer by email
        customers = ::Stripe::Customer.list(email: @user.email, limit: 1)
        customer = customers.data.first

        unless customer
          customer = ::Stripe::Customer.create(
            email: @user.email,
            name: @user.name,
            metadata: { datakeep_user_id: @user.id }
          )
        end

        @user.update!(stripe_customer_id: customer.id)
        customer.id
      end
    end
  end
end
