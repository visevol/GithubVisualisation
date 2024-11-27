class AddLastSyncAtOnRepositories < ActiveRecord::Migration[8.0]
  def change
    add_column :repositories, :last_synced_at, :datetime, default: nil
  end
end
