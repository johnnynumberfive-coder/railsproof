require "test_helper"
require "rails_proof/ai_test_planner"

class RailsProof::AiTestPlannerTest < ActiveSupport::TestCase
  class FakeAiClient
    attr_reader :received_context

    def initialize(suggestions)
      @suggestions = suggestions
    end

    def suggest_tests(context:)
      @received_context = context
      @suggestions
    end
  end

  test "sends Rails context to the AI client" do
    client = FakeAiClient.new([])

    planner = build_planner(client: client)

    planner.concerns

    assert_equal :model, client.received_context[:target_type]
    assert_equal "Post", client.received_context[:class_name]

    assert_includes(
      client.received_context[:source],
      "def publish!"
    )

    assert_includes(
      client.received_context[:existing_tests],
      "class PostTest"
    )

    assert_equal(
      [
        {
          type: :validation,
          validation: :presence,
          attribute: :title,
          description: "validates presence of title"
        }
      ],
      client.received_context[:deterministic_concerns]
    )
  end

  test "normalizes coverage suggestions" do
    client = FakeAiClient.new(
      [
        {
          "kind" => "coverage",
          "name" => "publish! sets published_at",
          "reason" => "The custom method changes publication state.",
          "test_code" => <<~RUBY
            test "publish! sets published_at" do
              post = Post.new

              post.publish!

              assert_not_nil post.published_at
            end
          RUBY
        }
      ]
    )

    concern = build_planner(client: client).concerns.first

    assert_equal :ai, concern[:type]
    assert_equal :coverage, concern[:kind]
    assert_equal "publish! sets published_at", concern[:name]
    assert_equal(
      "The custom method changes publication state.",
      concern[:reason]
    )
    assert_equal(
      "publish! sets published_at",
      concern[:description]
    )
    assert_includes(
      concern[:test_code],
      'test "publish! sets published_at" do'
    )
  end

  test "normalizes contract check suggestions" do
    client = FakeAiClient.new(
      [
        {
          kind: "contract_check",
          name: "exact match rejects partial matches",
          reason: "The method name implies equality but the implementation uses substring matching.",
          test_code: <<~RUBY
            test "exact match rejects partial matches" do
              post = Post.new(title: "Learning Rails")

              assert_not post.title_matches_exactly?("Rails")
            end
          RUBY
        }
      ]
    )

    concern = build_planner(client: client).concerns.first

    assert_equal :ai, concern[:type]
    assert_equal :contract_check, concern[:kind]
    assert_equal(
      "exact match rejects partial matches",
      concern[:name]
    )
    assert_includes(
      concern[:reason],
      "method name implies equality"
    )
    assert_includes(
      concern[:test_code],
      'assert_not post.title_matches_exactly?("Rails")'
    )
  end

  test "defaults suggestions without kind to coverage" do
    client = FakeAiClient.new(
      [
        {
          name: "publish! changes state",
          reason: "The custom method changes publication state."
        }
      ]
    )

    concern = build_planner(client: client).concerns.first

    assert_equal :coverage, concern[:kind]
  end

  test "allows the AI client to suggest no additional tests" do
    client = FakeAiClient.new([])

    planner = build_planner(client: client)

    assert_empty planner.concerns
  end

  test "allows planning-only suggestions without test code" do
    client = FakeAiClient.new(
      [
        {
          kind: "coverage",
          name: "publish! changes state",
          reason: "The custom method changes publication state."
        }
      ]
    )

    concern = build_planner(client: client).concerns.first

    assert_equal :coverage, concern[:kind]
    assert_equal "publish! changes state", concern[:name]
    refute concern.key?(:test_code)
  end

  test "rejects a non-array AI response" do
    client = FakeAiClient.new(
      {
        name: "something"
      }
    )

    planner = build_planner(client: client)

    assert_raises RailsProof::AiTestPlanner::InvalidResponse do
      planner.concerns
    end
  end

  test "rejects an unknown suggestion kind" do
    client = FakeAiClient.new(
      [
        {
          kind: "mystery",
          name: "something",
          reason: "Testing invalid kinds."
        }
      ]
    )

    planner = build_planner(client: client)

    error = assert_raises RailsProof::AiTestPlanner::InvalidResponse do
      planner.concerns
    end

    assert_includes(
      error.message,
      "kind must be coverage or contract_check"
    )
  end

  test "rejects a suggestion without a name" do
    client = FakeAiClient.new(
      [
        {
          kind: "coverage",
          reason: "There is behavior worth testing.",
          test_code: <<~RUBY
            test "something" do
              assert true
            end
          RUBY
        }
      ]
    )

    planner = build_planner(client: client)

    assert_raises RailsProof::AiTestPlanner::InvalidResponse do
      planner.concerns
    end
  end

  test "rejects a suggestion without a reason" do
    client = FakeAiClient.new(
      [
        {
          kind: "coverage",
          name: "publish! does something useful",
          test_code: <<~RUBY
            test "publish! does something useful" do
              assert true
            end
          RUBY
        }
      ]
    )

    planner = build_planner(client: client)

    assert_raises RailsProof::AiTestPlanner::InvalidResponse do
      planner.concerns
    end
  end

  test "rejects blank test code when test code is supplied" do
    client = FakeAiClient.new(
      [
        {
          kind: "coverage",
          name: "publish! changes state",
          reason: "The custom method changes publication state.",
          test_code: "   "
        }
      ]
    )

    planner = build_planner(client: client)

    assert_raises RailsProof::AiTestPlanner::InvalidResponse do
      planner.concerns
    end
  end

  private

  def build_planner(client:)
    RailsProof::AiTestPlanner.new(
      target_type: :model,
      class_name: "Post",
      source: <<~RUBY,
        class Post < ApplicationRecord
          validates :title, presence: true

          def publish!
            update!(published_at: Time.current)
          end
        end
      RUBY
      existing_tests: <<~RUBY,
        require "test_helper"

        class PostTest < ActiveSupport::TestCase
        end
      RUBY
      deterministic_concerns: [
        {
          type: :validation,
          validation: :presence,
          attribute: :title,
          description: "validates presence of title"
        }
      ],
      client: client
    )
  end
end