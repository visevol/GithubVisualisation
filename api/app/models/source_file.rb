class SourceFile < ApplicationRecord
  belongs_to :repository
  has_many :source_file_changes
  has_many :commits, through: :source_file_changes

  validates :filepath, uniqueness: { scope: :repository_id }

  def line_count(hash: nil)
    if hash
      # I know this is vulnerable to sql injections, i'm just messing around.
      # file = 534283
      # repository = 1
      ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT *
        FROM source_file_changes
        INNER JOIN commits AS pin ON pin.repository_id = #{repository_id} AND pin.commit_hash = '#{hash}'
        INNER JOIN commits ON TRUE
          AND commits.id = source_file_changes.commit_id
          AND commits.id < pin.id
          AND commits.for_file_size = 1
        LIMIT 10
      SQL
      # source_file_changes
        # .joins(:commit)
        # .joins(<<~JOIN)
          # INNER JOIN commits as commit_filters ON TRUE
            # AND commit_filters.commit_hash = '#{hash}'
            # AND commit_filters.id > commit.id
        # JOIN
        # .where(commit: { for_file_size: true })
    else
      source_file_changes
        .joins(:commit)
        .where(commit: { for_file_size: true })
        .pluck(Arel.sql('SUM(additions - deletions)'))
    end
  end
end
