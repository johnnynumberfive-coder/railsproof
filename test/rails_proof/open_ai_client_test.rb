require "test_helper"
require "json"
require "rails_proof/open_ai_client"

class RailsProof::OpenAiClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:output_text)

  class FakeResponses
    attr_reader :request

    def initialize(output:)
      @output = output
    end

    def create(**request)
      @request = request

      FakeResponse.new(@output)
    end
  end

  class FakeSdkClient
    attr_reader :responses

    def initialize(output:)
      @responses = FakeResponses.new(output: output)
    end
  end

  test "sends RailsProof context through the Responses API" do
    sdk_client = fake_client(
      suggestions: []
    )

    client = RailsProof::OpenAiClient.new(
      model: "test-model",
      sdk_client: sdk_client
    )

    client.suggest_tests(
      context: {
        target_type: :model,
        class_name: "Post",
        source: "class Post; end",
        existing_tests: "",
        deterministic_concerns: []
      }
    )

    request = sdk_client.responses.request

    assert_equal "test-model", request[:model]

    assert_equal :system, request[:input][0][:role]
    assert_includes request[:input][0][:content], "RailsProof"

    assert_equal :user, request[:input][1][:role]

    context = JSON.parse(request[:input][1][:content])

    assert_equal "model", context["target_type"]
    assert_equal "Post", context["class_name"]
    assert_equal "class Post; end", context["source"]
  end

  test "requests strict structured output with test code" do
    sdk_client = fake_client(
      suggestions: []
    )

    client = RailsProof::OpenAiClient.new(
      sdk_client: sdk_client
    )

    client.suggest_tests(
      context: {
        target_type: :model
      }
    )

    format = sdk_client
      .responses
      .request
      .dig(:text, :format)

    assert_equal :json_schema, format[:type]
    assert_equal "rails_proof_test_suggestions", format[:name]
    assert_equal true, format[:strict]
    assert_equal RailsProof::OpenAiClient::RESPONSE_SCHEMA, format[:schema]

    suggestion_schema =
      format[:schema]
        .dig(:properties, :suggestions, :items)

    assert_includes suggestion_schema[:required], "name"
    assert_includes suggestion_schema[:required], "reason"
    assert_includes suggestion_schema[:required], "test_code"
  end

  test "instructs the model to generate Minitest code" do
    sdk_client = fake_client(
      suggestions: []
    )

    client = RailsProof::OpenAiClient.new(
      sdk_client: sdk_client
    )

    client.suggest_tests(
      context: {
        target_type: :model
      }
    )

    prompt = sdk_client.responses.request[:input][0][:content]

    assert_includes prompt, "Minitest"
    assert_includes prompt, "test_code"
    assert_includes prompt, "exactly one complete Minitest test block"
    assert_includes prompt, "no Markdown code fences"
  end

  test "returns structured test suggestions with candidate code" do
    sdk_client = fake_client(
      suggestions: [
        {
          name: "publish! sets published_at",
          reason: "The method changes publication state.",
          test_code: <<~RUBY
            test "publish! sets published_at" do
              post = Post.new

              post.publish!

              assert_not_nil post.published_at
            end
          RUBY
        },
        {
          name: "publish! persists the change",
          reason: "The method uses persistent state.",
          test_code: <<~RUBY
            test "publish! persists the change" do
              post = Post.create!

              post.publish!

              assert_not_nil post.reload.published_at
            end
          RUBY
        }
      ]
    )

    client = RailsProof::OpenAiClient.new(
      sdk_client: sdk_client
    )

    suggestions = client.suggest_tests(
      context: {
        target_type: :model
      }
    )

    assert_equal 2, suggestions.count

    assert_equal(
      "publish! sets published_at",
      suggestions[0]["name"]
    )
    assert_equal(
      "The method changes publication state.",
      suggestions[0]["reason"]
    )
    assert_includes(
      suggestions[0]["test_code"],
      'test "publish! sets published_at" do'
    )

    assert_equal(
      "publish! persists the change",
      suggestions[1]["name"]
    )
    assert_equal(
      "The method uses persistent state.",
      suggestions[1]["reason"]
    )
    assert_includes(
      suggestions[1]["test_code"],
      'test "publish! persists the change" do'
    )
  end

  test "allows no additional AI suggestions" do
    sdk_client = fake_client(
      suggestions: []
    )

    client = RailsProof::OpenAiClient.new(
      sdk_client: sdk_client
    )

    assert_empty(
      client.suggest_tests(
        context: {
          target_type: :model
        }
      )
    )
  end

  test "rejects malformed JSON" do
    sdk_client = FakeSdkClient.new(
      output: "not json"
    )

    client = RailsProof::OpenAiClient.new(
      sdk_client: sdk_client
    )

    assert_raises RailsProof::OpenAiClient::Error do
      client.suggest_tests(
        context: {
          target_type: :model
        }
      )
    end
  end

  test "rejects a response without suggestions" do
    sdk_client = FakeSdkClient.new(
      output: JSON.generate(
        {
          something_else: []
        }
      )
    )

    client = RailsProof::OpenAiClient.new(
      sdk_client: sdk_client
    )

    assert_raises RailsProof::OpenAiClient::Error do
      client.suggest_tests(
        context: {
          target_type: :model
        }
      )
    end
  end

  private

  def fake_client(suggestions:)
    FakeSdkClient.new(
      output: JSON.generate(
        {
          suggestions: suggestions
        }
      )
    )
  end
end