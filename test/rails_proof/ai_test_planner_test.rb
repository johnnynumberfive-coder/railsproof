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

  test "normalizes AI suggestions with candidate test code" do
    client = FakeAiClient.new(
      [
        {
          "name" => "publish! sets published_at",
          "reason" => "The custom method changes publication state.",
          "test_code" => <<~RUBY
            test "publish! sets published_at" do
              post = Post.new

              post.publish!

              assert_not_nil post.published_at
            end
          RUBY
        },
        {
          name: "publish! persists the change",
          reason: "The method uses update! and should persist the timestamp.",
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

    planner = build_planner(client: client)

    concerns = planner.concerns

    assert_equal 2, concerns.count

    assert_equal :ai, concerns[0][:type]
    assert_equal "publish! sets published_at", concerns[0][:name]
    assert_equal(
      "The custom method changes publication state.",
      concerns[0][:reason]
    )
    assert_equal(
      "publish! sets published_at",
      concerns[0][:description]
    )
    assert_includes(
      concerns[0][:test_code],
      'test "publish! sets published_at" do'
    )

    assert_equal :ai, concerns[1][:type]
    assert_equal "publish! persists the change", concerns[1][:name]
    assert_equal(
      "The method uses update! and should persist the timestamp.",
      concerns[1][:reason]
    )
    assert_includes(
      concerns[1][:test_code],
      'test "publish! persists the change" do'
    )
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
          name: "publish! changes state",
          reason: "The custom method changes publication state."
        }
      ]
    )

    planner = build_planner(client: client)

    concern = planner.concerns.first

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

  test "rejects a suggestion without a name" do
    client = FakeAiClient.new(
      [
        {
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