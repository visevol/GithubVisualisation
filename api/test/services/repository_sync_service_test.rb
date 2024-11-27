require "test_helper"

class RepositorySyncServiceTest < ActiveSupport::TestCase
  def setup
    @repository = repositories(:example_repository)

    @gitland_repository_mock = mock("gitland_repository")
    @gitland_repository_mock.responds_like(Gitland::Repository.new(@repository))
    @gitland_repository_mock.stubs(:log).yields([])

    Gitland::Repository
      .expects(:new)
      .with(@repository)
      .returns(@gitland_repository_mock)
  end

  test "#index creates commits for the given repository" do
    stub_git_commit_history do
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

  test "#index creates source_file_changes for each commits" do
    stub_git_commit_history do
      <<~GIT_LOGS
        ||3ecab153fab78e61290892881e9a34d0df6fb7a0||Jonathan Lalande||2024-10-06||2024-10-06||l3gitpar3ntha5h yupt0ta11yl3git||some kind of subject
        3	0	README.md

        ||c8ab6fe877522729d4088dc7bce64b560d56a324||Jonathan Lalande||2024-10-07||2024-10-07||l3gitpar3ntha5h yupt0ta11yl3git||some kind of subject
        21	0	LICENSE
        0	3	README.md
        1	0	main.rb
         create mode 100644 LICENSE
         create mode 100644 main.rb
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    commit = @repository.commits.find_by(commit_hash: "3ecab153fab78e61290892881e9a34d0df6fb7a0")
    change = commit.source_file_changes.for_filepath("README.md")
    assert_equal(3, change.additions)
    assert_equal(0, change.deletions)

    commit = @repository.commits.find_by(commit_hash: "c8ab6fe877522729d4088dc7bce64b560d56a324")
    change = commit.source_file_changes.for_filepath("LICENSE")
    assert_equal(21, change.additions)
    assert_equal(0, change.deletions)

    change = commit.source_file_changes.for_filepath("README.md")
    assert_equal(0, change.additions)
    assert_equal(3, change.deletions)

    change = commit.source_file_changes.for_filepath("main.rb")
    assert_equal(1, change.additions)
    assert_equal(0, change.deletions)
  end

  test "#index creates source_files for each file in the log" do
    stub_git_commit_history do
      <<~GIT_LOGS
        ||3ecab153fab78e61290892881e9a34d0df6fb7a0||Jonathan Lalande||2024-10-06||2024-10-06||l3gitpar3ntha5h yupt0ta11yl3git||some kind of subject
        3	0	README.md

        ||c8ab6fe877522729d4088dc7bce64b560d56a324||Jonathan Lalande||2024-10-07||2024-10-07||l3gitpar3ntha5h yupt0ta11yl3git||some kind of subject
        21	0	LICENSE
        0	3	README.md
        1	0	main.rb
         create mode 100644 LICENSE
         create mode 100644 main.rb
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    assert_not_nil(@repository.source_files.find_by(filepath: "README.md"))
    assert_not_nil(@repository.source_files.find_by(filepath: "LICENSE"))
    assert_not_nil(@repository.source_files.find_by(filepath: "main.rb"))
  end

  test "#index creates source_files for binary files in the log" do
    stub_git_commit_history do
      <<~GIT_LOGS
        ||c5c6db27cef5623124dfb3f9aea34a04fd7c920f||Jonathan Lalande||2019-10-06||2019-10-06||c54b2f6989ba56fda64b7363e27ef99c4fa24346||Allow connection and channel creation via amqp
        -	-	amqp/amqp-xml-doc0-9-1.pdf
        -	-	amqp/amqp0-9-1.pdf
        459	0	amqp/amqp0-9-1.stripped.xml
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    assert_not_nil(@repository.source_files.find_by(filepath: "amqp/amqp-xml-doc0-9-1.pdf"))
    assert_not_nil(@repository.source_files.find_by(filepath: "amqp/amqp0-9-1.pdf"))
    assert_not_nil(@repository.source_files.find_by(filepath: "amqp/amqp0-9-1.stripped.xml"))
  end

  test "#index creates source_file_changes for merge commits" do
    stub_git_commit_history do
      # The empty lines here represents merge commits.
      # `git log --numstat` don't show stats about merge commits.
      #
      <<~GIT_LOGS
        ||fdeba4af9036551e029591e64780a5b5ad6aab98||Ryuta Kamizono||2024-10-13||2024-10-13||
        ||f942221d4629ce10a259a6adf92eccc559955770||Ryuta Kamizono||2024-10-13||2024-10-13||
        ||28a8fa54deaf87843cf653a2ce9684b14548c1e6||Yusuke Nakamura||2024-10-13||2024-10-13||
        6	2	guides/assets/javascripts/guides.js

        ||f9ec1ae62e21a278128a94b46f99a3928dd32f0e||Hartley McGuire||2024-10-12||2024-10-12||
      GIT_LOGS
    end

    stub_git_commit_history_for_line_counts do
      # `git log -m --first-parent --numstat` returns the accurate log of additions / deletions
      # that sums up to the final state of the repository.
      #
      <<~GIT_LOGS
        ||fdeba4af9036551e029591e64780a5b5ad6aab98||Ryuta Kamizono||2024-10-13||2024-10-13||
        9	0	activerecord/test/cases/date_time_test.rb
        4	0	activerecord/test/config.example.yml

        ||f942221d4629ce10a259a6adf92eccc559955770||Ryuta Kamizono||2024-10-13||2024-10-13||
        6	2	guides/assets/javascripts/guides.js

        ||f9ec1ae62e21a278128a94b46f99a3928dd32f0e||Hartley McGuire||2024-10-12||2024-10-12||
        1	1	guides/source/getting_started.md
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    commit = @repository.commits.find_by(commit_hash: "fdeba4af9036551e029591e64780a5b5ad6aab98")
    change = commit.source_file_changes.for_filepath("activerecord/test/cases/date_time_test.rb")
    assert_equal(9, change.additions)
    assert_equal(0, change.deletions)

    change = commit.source_file_changes.for_filepath("activerecord/test/config.example.yml")
    assert_equal(4, change.additions)
    assert_equal(0, change.deletions)

    commit = @repository.commits.find_by(commit_hash: "f942221d4629ce10a259a6adf92eccc559955770")
    change = commit.source_file_changes.for_filepath("guides/assets/javascripts/guides.js")
    assert_equal(6, change.additions)
    assert_equal(2, change.deletions)

    commit = @repository.commits.find_by(commit_hash: "f9ec1ae62e21a278128a94b46f99a3928dd32f0e")
    change = commit.source_file_changes.for_filepath("guides/source/getting_started.md")
    assert_equal(1, change.additions)
    assert_equal(1, change.deletions)
  end

  test "#index marks commits for changes ledger" do
    stub_git_commit_history do
      <<~GIT_LOGS
        ||f9ec1ae62e21a278128a94b46f99a3928dd32f0e||Hartley McGuire||2024-10-12||2024-10-12||
        ||28a8fa54deaf87843cf653a2ce9684b14548c1e6||Yusuke Nakamura||2024-10-13||2024-10-13||
        6	2	guides/assets/javascripts/guides.js

        ||f942221d4629ce10a259a6adf92eccc559955770||Ryuta Kamizono||2024-10-13||2024-10-13||
        ||fdeba4af9036551e029591e64780a5b5ad6aab98||Ryuta Kamizono||2024-10-13||2024-10-13||
      GIT_LOGS
    end

    stub_git_commit_history_for_line_counts do
      <<~GIT_LOGS
        ||f9ec1ae62e21a278128a94b46f99a3928dd32f0e||Hartley McGuire||2024-10-12||2024-10-12||
        1	1	guides/source/getting_started.md

        ||f942221d4629ce10a259a6adf92eccc559955770||Ryuta Kamizono||2024-10-13||2024-10-13||
        6	2	guides/assets/javascripts/guides.js

        ||fdeba4af9036551e029591e64780a5b5ad6aab98||Ryuta Kamizono||2024-10-13||2024-10-13||
        9	0	activerecord/test/cases/date_time_test.rb
        4	0	activerecord/test/config.example.yml
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    commits_for_ledger, commits = @repository.commits.order(:id).partition(&:for_changes_ledger)
    assert_equal([ "28a8fa54deaf87843cf653a2ce9684b14548c1e6" ], commits.map(&:commit_hash))
    assert_equal(
      [
        "f9ec1ae62e21a278128a94b46f99a3928dd32f0e",
        "f942221d4629ce10a259a6adf92eccc559955770",
        "fdeba4af9036551e029591e64780a5b5ad6aab98"
      ],
      commits_for_ledger.map(&:commit_hash)
    )
  end

  test "#index creates source_file_changes tagged with the type of changes" do
    stub_git_commit_history_for_line_counts { "" }
    stub_git_commit_history do
      <<~GIT_LOGS
        ||8fee13948c87b7a2497a74e4e43423de419161eb||Jonathan Lalande||2024-11-19||2024-11-19||0b8094d247cb6c22d21fd863222ba5bab59130ca||add random_file.rb
        1	0	src/random_file.rb
         create mode 100644 src/random_file.rb

        ||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||Jonathan Lalande||2024-11-19||2024-11-19||8fee13948c87b7a2497a74e4e43423de419161eb||update random_file.rb
        1	0	src/random_file.rb

        ||c1e50e105f8848b893bb58e2475cc52b8b170f99||Jonathan Lalande||2024-11-19||2024-11-19||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||remove random_file.rb
        0	2	src/random_file.rb
         delete mode 100644 src/random_file.rb
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    creation, modification, deletion = @repository
      .source_files
      .find_by(filepath: "src/random_file.rb")
      .source_file_changes

    assert_equal(1, creation.additions)
    assert_equal(0, creation.deletions)
    assert_equal("create", creation.category)

    assert_equal(1, modification.additions)
    assert_equal(0, modification.deletions)
    assert_equal("modify", modification.category)

    assert_equal(0, deletion.additions)
    assert_equal(2, deletion.deletions)
    assert_equal("delete", deletion.category)
  end

  test "#index creates source_file_changes for change ledger tagged with the type of changes" do
    stub_git_commit_history do
      <<~GIT_LOGS
        ||8fee13948c87b7a2497a74e4e43423de419161eb||Jonathan Lalande||2024-11-19||2024-11-19||0b8094d247cb6c22d21fd863222ba5bab59130ca||add random_file.rb
        ||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||Jonathan Lalande||2024-11-19||2024-11-19||8fee13948c87b7a2497a74e4e43423de419161eb||update random_file.rb
        ||c1e50e105f8848b893bb58e2475cc52b8b170f99||Jonathan Lalande||2024-11-19||2024-11-19||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||remove random_file.rb
      GIT_LOGS
    end
    stub_git_commit_history_for_line_counts  do
      <<~GIT_LOGS
        ||8fee13948c87b7a2497a74e4e43423de419161eb||Jonathan Lalande||2024-11-19||2024-11-19||0b8094d247cb6c22d21fd863222ba5bab59130ca||add random_file.rb
        1	0	src/random_file.rb
         create mode 100644 src/random_file.rb

        ||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||Jonathan Lalande||2024-11-19||2024-11-19||8fee13948c87b7a2497a74e4e43423de419161eb||update random_file.rb
        1	0	src/random_file.rb

        ||c1e50e105f8848b893bb58e2475cc52b8b170f99||Jonathan Lalande||2024-11-19||2024-11-19||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||remove random_file.rb
        0	2	src/random_file.rb
         delete mode 100644 src/random_file.rb
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    creation, modification, deletion = @repository
      .source_files
      .find_by(filepath: "src/random_file.rb")
      .source_file_changes

    assert_equal(1, creation.additions)
    assert_equal(0, creation.deletions)
    assert_equal("create", creation.category)

    assert_equal(1, modification.additions)
    assert_equal(0, modification.deletions)
    assert_equal("modify", modification.category)

    assert_equal(0, deletion.additions)
    assert_equal(2, deletion.deletions)
    assert_equal("delete", deletion.category)
  end

  test "#index summary parsing handles files with spaces in them" do
    stub_git_commit_history do
      <<~GIT_LOGS
        ||8fee13948c87b7a2497a74e4e43423de419161eb||Jonathan Lalande||2024-11-19||2024-11-19||0b8094d247cb6c22d21fd863222ba5bab59130ca||add space file A
        1	0	src/space file A
         create mode 100644 src/space file A

        ||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||Jonathan Lalande||2024-11-19||2024-11-19||8fee13948c87b7a2497a74e4e43423de419161eb||add space file B
      GIT_LOGS
    end

    stub_git_commit_history_for_line_counts do
      <<~GIT_LOGS
        ||a151de81e6f90d9c0745ca638695c4bfe6b46ba6||Jonathan Lalande||2024-11-19||2024-11-19||8fee13948c87b7a2497a74e4e43423de419161eb||add space file B
        1	0	src/space file B
         create mode 100644 src/space file B
      GIT_LOGS
    end

    RepositorySyncService.new(@repository).index

    space_file_a = @repository.source_files.find_by(filepath: "src/space file A")
    assert_equal("create", space_file_a.source_file_changes.first.category)

    space_file_b = @repository.source_files.find_by(filepath: "src/space file B")
    assert_equal("create", space_file_b.source_file_changes.first.category)
  end

  test "#index sets the last_synced_at column on the repository once it completes" do
    freeze_time do
      assert_nil(@repository.last_synced_at)

      RepositorySyncService.new(@repository).index

      assert_equal(DateTime.current, @repository.last_synced_at)
    end
  end

  private

  def stub_git_commit_history(&block)
    logs_enumerator = (block.call).lines.each

    @gitland_repository_mock
      .expects(:log)
      .with(format: "||%H||%aN||%cs||%as||%P||%s")
      .yields(logs_enumerator)
      .at_least_once
  end

  def stub_git_commit_history_for_line_counts(&block)
    logs_enumerator = (block.call).lines.each

    @gitland_repository_mock
      .expects(:log)
      .with(format: "||%H||%aN||%cs||%as||%P||%s", first_parent: true)
      .yields(logs_enumerator)
      .at_least_once
  end
end
