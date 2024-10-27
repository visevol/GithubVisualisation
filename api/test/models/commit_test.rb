require "test_helper"

class CommitTest < ActiveSupport::TestCase
  test "commit_hash is required" do
    commit = commits(:rails_4ad93b)
    commit.commit_hash = ""

    assert_not(commit.valid?)
    assert_equal([ "can't be blank" ], commit.errors[:commit_hash])
  end

  test "cannot have two commit with the same hash in the same repository" do
    duplicated_commit = commits(:rails_4ad93b).dup
    duplicated_commit.save

    assert_not(duplicated_commit.valid?)
    assert_equal([ "has already been taken" ], duplicated_commit.errors[:commit_hash])
  end

  test "two commits can have the same hash accross repositories" do
    original_commit = commits(:rails_4ad93b)

    commit = original_commit.dup
    commit.repository = repositories(:moodle)
    commit.save

    assert(commit.valid?)
  end
end
