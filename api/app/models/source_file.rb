class SourceFile < ApplicationRecord
  belongs_to :repository
  has_many :source_file_changes
  has_many :commits, through: :source_file_changes

  validates :filepath, uniqueness: { scope: :repository_id }

  def file_size
    source_file_changes
      .joins(:commit)
      .where(commit: { for_file_size: true })
      .pluck(Arel.sql('SUM(additions - deletions)'))
  end
end
