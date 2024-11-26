class CreateRepositorySyncAttempt < ActiveRecord::Migration[8.0]
  def change
    create_table :repository_sync_attempts do |t|
      t.references :repository
      t.string :status
      t.timestamps
    end
  end
end
