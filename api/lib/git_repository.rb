class GitRepository
  def initialize(remote_url)
    @remote_url = remote_url
  end

  def clone
    Git.clone(@remote_url, temp_directory)
  end

  #
  # Calls `git log` on the repository.
  # Yields an enumerator of lines on the output.
  #
  # Example:
  #
  #   repo = GitRepository.new("https://github.com/rails/rails")
  #   repo.clone
  #   repo.logs do |logs|
  #     logs.each do |line|
  #       print(line)
  #     end
  #   end
  #
  #   output:
  #     > " create mode 100644 railties/generators/templates/model.erb\n"
  #     > " create mode 100644 railties/generators/templates/model_test.erb\n"
  #     > " create mode 100644 railties/helpers/abstract_application.rb\n"
  #     > " create mode 100644 railties/helpers/application_helper.rb\n"
  #     > " create mode 100644 railties/helpers/test_helper.rb\n"
  #     > " create mode 100644 railties/html/404.html\n"
  #     > " create mode 100644 railties/html/500.html\n"
  #     > " create mode 100644 railties/html/index.html\n"
  #     > " create mode 100644 railties/lib/code_statistics.rb\n"
  #
  # ==== Options
  # since:  only show commits more recent than that date (DateTime)
  # before: only show commits older than that date (DateTime)
  # format: pretty print format for commits.
  #         This is passed directly to the `--pretty=format:"#{format}"` option
  #         See `man git log` for documentation about available formats.
  #
  def logs(
    with_first_parent: false,
    since: nil,
    before: nil,
    format: nil
  )
    return unless block_given?

    command = [ "log" ]
    command << "--reverse"
    command << "--numstat"
    command << "--summary"
    command << "--no-renames"
    command << "-m" if with_first_parent
    command << "--first-parent" if with_first_parent
    command << "--since=#{since.strftime("%Y-%m-%d")}" if since
    command << "--until=#{before.strftime("%Y-%m-%d")}" if before
    command << "--pretty=format:#{format}" if format

    Tempfile.create(binmode: true) do |f|
      cli.run(*command, out: f, err: STDERR, chdir: temp_directory, normalize: true, chomp: true, merge: false)
      f.rewind
      yield f.each_line
    end
  end

  private

  def temp_directory
    @temp_directory ||= Dir.mktmpdir
  end

  def cli
    @cli ||= Git::CommandLine.new({}, "/usr/bin/git", [], Logger.new("/dev/null"))
  end
end
