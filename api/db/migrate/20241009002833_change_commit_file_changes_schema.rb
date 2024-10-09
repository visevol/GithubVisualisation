class ChangeCommitFileChangesSchema < ActiveRecord::Migration[8.0]
  def change
    drop_table(:commit_file_changes)
    create_table :commit_file_changes do |t|
      t.references :repository, index: false
      t.string :commit_hash
      t.string :filepath
      t.integer :additions, default: 0
      t.integer :deletions, default: 0

      t.index([:repository_id, :commit_hash])
    end
  end
end
