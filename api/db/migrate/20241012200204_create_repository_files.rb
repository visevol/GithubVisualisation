class CreateRepositoryFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :repository_files do |t|
      t.references :repository
      t.string :filepath

      t.index [ :repository_id, :filepath ], unique: true
    end
  end
end
