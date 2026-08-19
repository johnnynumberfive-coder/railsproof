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

  test "requests strict structured output with suggestion kind" do
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

    assert_includes suggestion_schema[:required], "kind"
    assert_includes suggestion_schema[:required], "name"
    assert_includes suggestion_schema[:required], "reason"
    assert_includes suggestion_schema[:required], "test_code"

    assert_equal(
      %w[coverage contract_check],
      suggestion_schema.dig(:properties, :kind, :enum)
    )
  end

  test "instructs the model to generate coverage and contract checks" do
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
    assert_includes prompt, "coverage"
    assert_includes prompt, "contract_check"
    assert_includes prompt,
      "Do not assume that the current implementation is correct"
    assert_includes prompt,
      "do NOT also"
    assert_includes prompt,
      "exactly one complete Minitest test block"
    assert_includes prompt, "no Markdown code fences"
  end

  test "returns structured coverage and contract check suggestions" do
    sdk_client = fake_client(
      suggestions: [
        {
          kind: "coverage",
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
          kind: "contract_check",
          name: "exact match rejects partial matches",
          reason: "The public method name implies exact equality but the implementation uses substring matching.",
          test_code: <<~RUBY
            test "exact match rejects partial matches" do
              post = Post.new(title: "Learning Rails")

              assert_not post.title_matches_exactly?("Rails")
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

    assert_equal "coverage", suggestions[0]["kind"]
    assert_equal(
      "publish! sets published_at",
      suggestions[0]["name"]
    )

    assert_equal "contract_check", suggestions[1]["kind"]
    assert_equal(
      "exact match rejects partial matches",
      suggestions[1]["name"]
    )
    assert_includes(
      suggestions[1]["test_code"],
      'assert_not post.title_matches_exactly?("Rails")'
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