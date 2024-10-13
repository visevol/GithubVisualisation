class RepositorySyncService
  COMMIT_BATCH_SIZE = 2500

  def initialize(repository)
    @repository = repository
    @git_repo = GitRepository.new(@repository.remote_url)
    @commits = []
    @files = {}
  end

  def index
    @git_repo.clone

    extract_commit_history
    extract_commit_history_for_file_sizes
  end

  private

  def extract_commit_history
    @git_repo.logs(format: "||%H||%aN||%cs||%as||") do |logs|
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
          change = commit_file_change_data_from_line(line, current_commit_hash)
          filepath = change.delete(:filepath)

          (@files[filepath] ||= []) << change
        end
      end

      persist_current_batch
    end
  end

  def extract_commit_history_for_file_sizes
    @git_repo.logs(with_first_parent: true, format: "||%H||%aN||%cs||%as||") do |logs|
      current_commit_hash = nil

      logs.each do |line|
        line.force_encoding("utf-8")

        next if line == ""

        if line[0] == "|"
          persist_current_batch(for_file_size: true) if @commits.size >= COMMIT_BATCH_SIZE

          commit = commit_data_from_line(line)
          commit[:for_file_size] = true
          current_commit_hash = commit[:commit_hash]
          @commits << commit
        elsif Integer(line[0], exception: false)
          change = commit_file_change_data_from_line(line, current_commit_hash)
          filepath = change.delete(:filepath)

          (@files[filepath] ||= []) << change
        end
      end

      persist_current_batch(for_file_size: true)
    end
  end

  def persist_current_batch(for_file_size: false)
    if for_file_size
      Commit
        .where(commit_hash: @commits.map { _1[:commit_hash] })
        .update_all(for_file_size: true)
    else
      Commit.insert_all(@commits)
    end
    SourceFile.insert_all(@files.keys.map { |filepath| source_file_attribute(filepath) })

    commits_by_hash = Commit
      .select(:id, :commit_hash)
      .where(repository: @repository, commit_hash: @commits.map { _1[:commit_hash] })
      .index_by(&:commit_hash)

    source_files_by_filepath = SourceFile
      .where(repository: @repository, filepath: @files.keys)
      .index_by(&:filepath)

    @files.each do |filepath, changes|
      changes.map! do |change|
        commit = commits_by_hash[change[:commit_hash]]
        source_file = source_files_by_filepath[filepath]

        {
          commit_id: commit.id,
          source_file_id: source_file.id,
          additions: change[:additions],
          deletions: change[:deletions]
        }
      end
    end

    SourceFileChange.insert_all(@files.values.flatten)

    @commits = []
    @files = {}
  end

  def source_file_attribute(filepath)
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
