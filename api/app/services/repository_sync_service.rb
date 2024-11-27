class RepositorySyncService
  def initialize(repository)
    @repository = repository
  end

  def index
    gitland_repository = Gitland::Repository.new(@repository)

    @repository.transaction do
      extract_full_commit_history(gitland_repository)
      extract_commit_history_for_changes_ledger(gitland_repository)

      @repository.update!(last_synced_at: DateTime.current)
    end
  end

  private

  #
  # A batch of commits, source_files and changes to persist.
  #
  class Batch
    MAX_COMMIT_BATCH_SIZE = 2500

    attr_reader(:commits)

    def initialize
      @commits = []
      @files = {}
    end

    def add_commit(commit)
      @commits << commit
    end

    def add_file_change(file_change)
      (@files[file_change[:filepath]] ||= []) << file_change
    end

    def size
      @commits.size
    end

    def full?
      size >= MAX_COMMIT_BATCH_SIZE
    end

    def filepaths
      @files.keys
    end

    def file_changes
      @files.values.flatten
    end

    def set_category_to_file_change(commit_hash, filepath, category)
      @files[filepath]
        .find { |file_change| file_change[:commit_hash] == commit_hash }
        .then { |file_change| file_change[:category] = category }
    end

    def reset
      @commits = []
      @files = {}
    end
  end

  def extract_full_commit_history(gitland_repository)
    batch = Batch.new
    current_commit_hash = nil

    gitland_repository.log(format: "||%H||%aN||%cs||%as||%P||%s") do |logs|
      logs.each do |line|
        line.force_encoding("utf-8")

        if line_is_a_commit?(line)
          commit_batch(batch) if batch.full?

          commit = commit_attributes_from_line(line)
          current_commit_hash = commit[:commit_hash]

          batch.add_commit(commit)
        elsif line_is_a_file_change?(line)
          change = file_change_attributes_from_line(line, current_commit_hash)
          batch.add_file_change(change)
        elsif line_is_a_summary?(line)
          category, filepath = parse_summary_line(line)
          batch.set_category_to_file_change(current_commit_hash, filepath, category)
        end
      end

      commit_batch(batch)
    end
  end

  def extract_commit_history_for_changes_ledger(gitland_repository)
    batch = Batch.new
    current_commit_hash = nil

    gitland_repository.log(format: "||%H||%aN||%cs||%as||%P||%s", first_parent: true) do |logs|
      logs.each do |line|
        line.force_encoding("utf-8")

        if line_is_a_commit?(line)
          commit_batch_for_changes_ledger(batch) if batch.full?

          commit = commit_attributes_from_line(line)
          current_commit_hash = commit[:commit_hash]

          batch.add_commit(commit)
        elsif line_is_a_file_change?(line)
          change = file_change_attributes_from_line(line, current_commit_hash)
          batch.add_file_change(change)
        elsif line_is_a_summary?(line)
          category, filepath = parse_summary_line(line)
          batch.set_category_to_file_change(current_commit_hash, filepath, category)
        end
      end

      commit_batch_for_changes_ledger(batch)
    end
  end

  def commit_batch(batch)
    @repository.commits.insert_all(batch.commits)
    @repository.source_files.insert_all(batch.filepaths.map { { filepath: _1 } })

    commits_by_hash = @repository.commits
      .select(:id, :commit_hash)
      .where(commit_hash: batch.commits.map { _1[:commit_hash] })
      .index_by(&:commit_hash)

    source_files_by_filepath = @repository.source_files
      .select(:id, :filepath)
      .where(filepath: batch.filepaths)
      .index_by(&:filepath)

    SourceFileChange.insert_all(
      batch.file_changes.map do |change|
        commit = commits_by_hash[change[:commit_hash]]
        source_file = source_files_by_filepath[change[:filepath]]

        {
          commit_id: commit.id,
          source_file_id: source_file.id,
          additions: change[:additions],
          deletions: change[:deletions],
          category: change[:category]
        }
      end
    )

    batch.reset
  end

  def commit_batch_for_changes_ledger(batch)
    @repository.source_files.insert_all(batch.filepaths.map { { filepath: _1 } })

    commit_scope = @repository.commits.where(commit_hash: batch.commits.map { _1[:commit_hash] })
    commit_scope.update_all(for_changes_ledger: true)
    commits_by_hash = commit_scope.select(:id, :commit_hash).index_by(&:commit_hash)

    source_files_by_filepath = @repository.source_files
      .select(:id, :filepath)
      .where(filepath: batch.filepaths)
      .index_by(&:filepath)

    SourceFileChange.insert_all(
      batch.file_changes.map do |change|
        commit = commits_by_hash[change[:commit_hash]]
        source_file = source_files_by_filepath[change[:filepath]]

        {
          commit_id: commit.id,
          source_file_id: source_file.id,
          additions: change[:additions],
          deletions: change[:deletions],
          category: change[:category]
        }
      end
    )

    batch.reset
  end

  def line_is_a_commit?(line)
    line[0] == "|"
  end

  def line_is_a_file_change?(line)
    Integer(line[0], exception: false) || line[0] == "-"
  end

  def line_is_a_summary?(line)
    line.strip.start_with?(
      SourceFileChange::FILE_CHANGE_CREATE_CATEGORY,
      SourceFileChange::FILE_CHANGE_DELETE_CATEGORY
    )
  end

  def commit_attributes_from_line(line)
    _, hash, author, committer_date, author_date, parent_hashes, subject = line.split("||")
    {
      commit_hash: hash,
      author: author,
      committer_date: DateTime.parse(committer_date),
      author_date: DateTime.parse(author_date),
      parent_hashes: parent_hashes.split(" "),
      subject: subject
    }
  end

  def file_change_attributes_from_line(line, commit_hash)
    additions, deletions, filepath = line.split("\t", 3)
    {
      commit_hash: commit_hash,
      filepath: filepath.strip,
      category: SourceFileChange::FILE_CHANGE_MODIFY_CATEGORY,
      additions: additions,
      deletions: deletions
    }
  end

  def parse_summary_line(line)
    # Parse a `summary` line generated by: git log --summary
    # Example of summary lines:
    #   create mode 100644 guides/source/8_1_release_notes.md
    #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  indicates that the file was created in the commmit.
    #
    #   delete mode 100644 guides/source/8_1_release_notes.md
    #   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^  indicates that the file was deleted in the commmit.
    category, _, _, filepath = line.strip.split(" ", 4)
    return category, filepath
  end
end
