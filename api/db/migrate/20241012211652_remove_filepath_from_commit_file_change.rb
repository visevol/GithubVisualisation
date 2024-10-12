class RemoveFilepathFromCommitFileChange < ActiveRecord::Migration[8.0]
  def change
    remove_column :commit_file_changes, :filepath
  end
end
