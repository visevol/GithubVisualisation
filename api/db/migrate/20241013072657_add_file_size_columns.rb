class AddFileSizeColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :commits, :for_file_size, :boolean, default: false

    add_index :source_file_changes, [:commit_id, :source_file_id], unique: true
  end
end
