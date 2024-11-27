require "test_helper"
require "minitest/mock"

class RepositoriesControllerTest < ActionDispatch::IntegrationTest
  test "#show returns 404 when the repository does not exists" do
    get "/repositories/9999999999"

    assert_response(:not_found)
  end

  test "#show returns 200 when the repository exists" do
    repository = repositories(:rails)

    get "/repositories/#{repository.id}"

    assert_response(:ok)
    assert_equal(
      {
        "id" => repository.id,
        "name" => "rails",
        "domain" => "github.com",
        "path" => "/rails/rails",
        "url" => "https://github.com/rails/rails",
        "created_at" => repository.created_at.as_json,
        "updated_at" => repository.updated_at.as_json,
        "last_synced_at" => nil
      },
      response.parsed_body
    )
  end

  test "#create returns 200 if the repository already exists" do
    repository = repositories(:rails)

    params = { url: "https://github.com/rails/rails" }
    post("/repositories", params: params, as: :json)

    assert_response(:ok)
    assert_equal(repository.id, response.parsed_body[:id])
  end

  test "#create returns 404 if the remote repository does not exists" do
    stub_remote_repository(nil) do
      params = { url: "https://github.com/example/random-repo-123456789" }
      post("/repositories", params: params, as: :json)

      assert_response(:not_found)
    end
  end

  test "#create returns 201 if the repository is created" do
    remote_repository = RemoteRepository.new(
      name: "discourse",
      description: "A platform for community discussion. Free, open, simple.",
      url: "https://github.com/discourse/discourse"
    )

    stub_remote_repository(remote_repository) do
      params = { url: "https://github.com/discourse/discourse" }
      post("/repositories", params: params, as: :json)

      assert_response(:created)
    end
  end

  test "#search returns 404 if the repository does not exists in our database and on the remote" do
    stub_remote_repository(nil) do
      get("/repositories/search?url=https://github.com/non-existing/repository", as: :json)

      assert_response(:not_found)
    end
  end

  test "#search returns 200 if the repository does not exists in our database, but exists on the remote" do
    remote_repository = RemoteRepository.new(
      name: "discourse",
      description: "A platform for community discussion. Free, open, simple.",
      url: "https://github.com/discourse/discourse"
    )

    stub_remote_repository(remote_repository) do
      get("/repositories/search?url=https://github.com/discourse/discourse", as: :json)

      assert_response(:ok)
      assert_equal(
        {
          "repository" => nil,
          "remote_repository" => {
            "name" => "discourse",
            "description" => "A platform for community discussion. Free, open, simple.",
            "domain" => "github.com",
            "path" => "/discourse/discourse",
            "url" => "https://github.com/discourse/discourse"
          }
        },
        response.parsed_body
      )
    end
  end

  test "#search returns 200 if the repository exists in our database, but not on the remote" do
    repository = repositories(:moodle)

    stub_remote_repository(nil) do
      get("/repositories/search?url=#{repository.remote_url}", as: :json)

      assert_response(:ok)
      assert_equal(
        {
          "repository" => {
            "id" => repository.id,
            "name" => "moodle",
            "domain" => "github.com",
            "path" => "/moodle/moodle",
            "url" => "https://github.com/moodle/moodle",
            "created_at" => repository.created_at.as_json,
            "updated_at" => repository.updated_at.as_json,
            "last_synced_at" => nil
          },
          "remote_repository" => nil
        },
        response.parsed_body
      )
    end
  end

  test "#search returns 200 if the repository exists in our database and on the remote" do
    repository = repositories(:moodle)
    remote_repository = RemoteRepository.new(
      name: "moodle",
      description: "Moodle - the world's open source learning platform",
      url: "https://github.com/moodle/moodle"
    )

    stub_remote_repository(remote_repository) do
      get("/repositories/search?url=#{repository.remote_url}", as: :json)

      assert_response(:ok)
      assert_equal(
        {
          "repository" => {
            "id" => repository.id,
            "name" => "moodle",
            "domain" => "github.com",
            "path" => "/moodle/moodle",
            "url" => "https://github.com/moodle/moodle",
            "created_at" => repository.created_at.as_json,
            "updated_at" => repository.updated_at.as_json,
            "last_synced_at" => nil
          },
          "remote_repository" => {
            "name" => "moodle",
            "description" => "Moodle - the world's open source learning platform",
            "domain" => "github.com",
            "path" => "/moodle/moodle",
            "url" => "https://github.com/moodle/moodle"
          }
        },
        response.parsed_body
      )
    end
  end

  private

  def stub_remote_repository(remote_repository)
    mock = Minitest::Mock.new
    mock.expect(:fetch_remote_repository, remote_repository, [ String ])

    GithubService.stub(:new, mock) do
      yield
    end
  end
end
