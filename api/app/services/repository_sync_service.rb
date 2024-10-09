class RepositorySyncService
  def initialize(repository)
    @repository = repository
  end

  def index
    git_repo = GitRepository.new(@repository.remote_url)
    git_repo.clone
    git_repo.logs(format: "||%H||%aN||%cs||%as||") do |logs|
      commit_hash = nil
      commits = []
      changes = []

      logs.each do |line|
        line.force_encoding("utf-8")

        next if line == ""

        if line[0] == "|"
          if commits.size > 500
            Commit.insert_all(commits)
            CommitFileChange.insert_all(changes)

            commits = []
            changes = []
          end

          data = commit_data_from_line(line)
          commits << data
          commit_hash = data[:commit_hash]
        elsif Integer(line[0], exception: false)
          changes << commit_file_change_data_from_line(line, commit_hash)
        end
      end

      unless commits.empty?
        Commit.insert_all(commits)
        CommitFileChange.insert_all(changes)
      end
    end
  end

  private

  def commit_data_from_line(line)
    _, hash, author, committer_date, author_date = line.split("||")
    {
      repository_id: @repository.id,
      commit_hash: hash,
      author: author,
      committer_date: DateTime.parse(committer_date),
      author_date: DateTime.parse(author_date)
    }
  end

  def commit_file_change_data_from_line(line, commit_hash)
    additions, deletions, filepath = line.split("\t", 3)
    {
      repository_id: @repository.id,
      commit_hash: commit_hash,
      filepath: filepath.strip,
      additions: additions,
      deletions: deletions
    }
  end
end
