class Commit < ApplicationRecord
  belongs_to :repository
  has_many :file_changes,
    class_name: "CommitFileChange",
    primary_key: [:repository_id, :commit_hash],
    foreign_key: [:repository_id, :commit_hash]

  validates :commit_hash,
    presence: true,
    uniqueness: { scope: :repository_id }
end
