class RepositorySyncService
  COMMIT_BATCH_SIZE = 2500

  def initialize(repository)
    @repository = repository
    @commits = []
    @files = {}
  end

  def index
    git_repo = GitRepository.new(@repository.remote_url)
    git_repo.clone
    git_repo.logs(format: "||%H||%aN||%cs||%as||") do |logs|
      current_commit_hash = nil

      logs.each do |line|
        line.force_encoding("utf-8")

        next if line == ""

        if line[0] == "|"
          persist_current_batch if @commits.size >= COMMIT_BATCH_SIZE

          commit = commit_data_from_line(line)
          current_commit_hash = commit[:commit_hash]
          @commits << commit
        elsif Integer(line[0], exception: false)
          file_change = commit_file_change_data_from_line(line, current_commit_hash)
          filepath = file_change.delete(:filepath)
          (@files[filepath] ||= []) << file_change
        end
      end

      persist_current_batch
    end
  end

  private

  def persist_current_batch
    Commit.insert_all(@commits)
    RepositoryFile.insert_all(@files.keys.map { |filepath| file_attribute(filepath) })

    commits_by_hash = Commit
      .select(:id, :commit_hash)
      .where(repository: @repository, commit_hash: @commits.map { _1[:commit_hash] })
      .index_by(&:commit_hash)

    files_by_filepath = RepositoryFile
      .where(repository: @repository, filepath: @files.keys)
      .index_by(&:filepath)

    @files.each do |filepath, changes|
      changes.map! do |change|
        commit = commits_by_hash[change.delete(:commit_hash)]
        file = files_by_filepath[filepath]

        change[:commit_id] = commit.id
        change[:repository_file_id] = file.id
        change
      end
    end

    CommitFileChange.insert_all(@files.values.flatten)

    @commits = []
    @files = {}
  end

  def file_attribute(filepath)
    { repository_id: @repository.id, filepath: filepath }
  end

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
      commit_hash: commit_hash,
      filepath: filepath.strip,
      additions: additions,
      deletions: deletions
    }
  end
end
