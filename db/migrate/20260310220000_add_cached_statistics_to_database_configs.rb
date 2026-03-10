# frozen_string_literal: true

class AddCachedStatisticsToDatabaseConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :database_configs, :cached_statistics, :jsonb
    add_column :database_configs, :statistics_updated_at, :datetime
  end
end
