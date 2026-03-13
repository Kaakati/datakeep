# frozen_string_literal: true

class AddStripeHostedInvoiceUrlToEnterpriseQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :enterprise_quotes, :stripe_hosted_invoice_url, :string
  end
end
