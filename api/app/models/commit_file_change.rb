class CommitFileChange < ApplicationRecord
  belongs_to :repository
  belongs_to :commit,
    primary_key: [:repository_id, :commit_hash],
    foreign_key: [:repository_id, :commit_hash]
end
