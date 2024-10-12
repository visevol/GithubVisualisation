class CommitFileChange < ApplicationRecord
  belongs_to :commit
  belongs_to :file, class_name: "RepositoryFile", foreign_key: :repository_file_id
end
