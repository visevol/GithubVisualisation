class Commit < ApplicationRecord
  belongs_to :repository
  has_many :commit_file_changes
  has_many :modified_files, through: :commit_file_changes, source: :file


  validates :commit_hash,
    presence: true,
    uniqueness: { scope: :repository_id }
end
