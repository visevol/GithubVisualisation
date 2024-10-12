class AddRepositoryFileIdToFileChange < ActiveRecord::Migration[8.0]
  def change
    add_reference :commit_file_changes, :repository_file, null: false
  end
end
