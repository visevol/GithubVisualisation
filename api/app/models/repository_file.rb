class RepositoryFile < ApplicationRecord
  belongs_to :repository
  has_many :commit_file_changes
  has_many :commits, through: :commit_file_changes
end
