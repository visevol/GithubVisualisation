require "test_helper"

class RepositorySyncServiceTest < ActiveSupport::TestCase
  def setup
    @repository = repositories(:example_repository)
  end

  test "#index creates commits for the given repository" do
    stub_git_repository_logs do
      <<~GIT_LOGS
        ||71c23127bf7bad405dd3e8e29f9394140882898c||Jonathan Lalande||2024-10-06||2024-10-06||
        2	0	README.md
         create mode 100644 README.md

        ||3ecab153fab78e61290892881e9a34d0df6fb7a0||Jonathan Lalande||2024-10-10||2024-10-10||
        3	0	README.md
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    commit_a = @repository.commits.find_by(commit_hash: "71c23127bf7bad405dd3e8e29f9394140882898c")
    assert_equal("Jonathan Lalande", commit_a.author)
    assert_equal(DateTime.parse("2024-10-06"), commit_a.committer_date.to_datetime)
    assert_equal(DateTime.parse("2024-10-06"), commit_a.author_date.to_datetime)

    commit_b = @repository.commits.find_by(commit_hash: "3ecab153fab78e61290892881e9a34d0df6fb7a0")
    assert_equal("Jonathan Lalande", commit_b.author)
    assert_equal(DateTime.parse("2024-10-10"), commit_b.committer_date.to_datetime)
    assert_equal(DateTime.parse("2024-10-10"), commit_b.author_date.to_datetime)
  end

  test "#index creates a repository_files for each tracked files in the repo" do
    stub_git_repository_logs do
      <<~GIT_LOGS
        ||3ecab153fab78e61290892881e9a34d0df6fb7a0||Jonathan Lalande||2024-10-06||2024-10-06
        3	0	README.md

        ||c8ab6fe877522729d4088dc7bce64b560d56a324||Jonathan Lalande||2024-10-07||2024-10-07
        21	0	LICENSE
        0	3	README.md
        1	0	main.rb
         create mode 100644 LICENSE
         create mode 100644 main.rb
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    assert_not_nil(@repository.files.find_by(filepath: "README.md"))
    assert_not_nil(@repository.files.find_by(filepath: "LICENSE"))
    assert_not_nil(@repository.files.find_by(filepath: "main.rb"))
  end

  test "#index creates commit_file_changes for each commits" do
    stub_git_repository_logs do
      <<~GIT_LOGS
        ||3ecab153fab78e61290892881e9a34d0df6fb7a0||Jonathan Lalande||2024-10-06||2024-10-06
        3	0	README.md

        ||c8ab6fe877522729d4088dc7bce64b560d56a324||Jonathan Lalande||2024-10-07||2024-10-07
        21	0	LICENSE
        0	3	README.md
        1	0	main.rb
         create mode 100644 LICENSE
         create mode 100644 main.rb
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    commit = @repository.commits.find_by(commit_hash: "3ecab153fab78e61290892881e9a34d0df6fb7a0")
    change = commit.file_changes.joins(:file).find_by(file: { filepath: "README.md" })
    assert_equal(3, change.additions)
    assert_equal(0, change.deletions)

    commit = @repository.commits.find_by(commit_hash: "c8ab6fe877522729d4088dc7bce64b560d56a324")
    change = commit.file_changes.joins(:file).find_by(file: { filepath: "LICENSE" })
    assert_equal(21, change.additions)
    assert_equal(0, change.deletions)

    change = commit.file_changes.joins(:file).find_by(file: { filepath: "README.md" })
    assert_equal(0, change.additions)
    assert_equal(3, change.deletions)

    change = commit.file_changes.joins(:file).find_by(file: { filepath: "main.rb" })
    assert_equal(1, change.additions)
    assert_equal(0, change.deletions)
  end

  private

  def stub_git_repository_logs(&block)
    logs_enumerator = (block.call).lines.each

    GitRepository.any_instance.expects(:clone).returns(nil)
    GitRepository.any_instance
      .expects(:logs)
      .with(format: "||%H||%aN||%cs||%as||")
      .yields(logs_enumerator)
      .once
  end
end
