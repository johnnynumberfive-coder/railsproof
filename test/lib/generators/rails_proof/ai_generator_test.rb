require "test_helper"
require "generators/rails_proof/test/test_generator"

class RailsProof::AiGeneratorTest < Rails::Generators::TestCase
  tests RailsProof::TestGenerator
  destination Rails.root.join("tmp/ai_generators")
  setup :prepare_destination

  setup do
    @previous_ai_client = RailsProof.ai_client

    @ai_client = RailsProof::TestAiClient.new(
      suggestions: [
        {
          name: "matches titles case-insensitively",
          reason: "The custom method downcases both values before matching.",
          test_code: <<~RUBY
            test "title_matches finds substrings case insensitively" do
              post = Post.new(title: "Hello World")

              assert post.title_matches?("hello")
          RUBY
        }
      ]
    )

    RailsProof.ai_client = @ai_client

    mkdir_p File.join(destination_root, "app/models")

    File.write(
      File.join(destination_root, "app/models/post.rb"),
      <<~RUBY
        class Post < ApplicationRecord
          belongs_to :user

          validates :title, presence: true

          def title_matches?(query)
            return false if query.blank?

            title.to_s.downcase.include?(query.to_s.downcase)
          end
        end
      RUBY
    )
  end

  teardown do
    RailsProof.ai_client = @previous_ai_client
  end

  test "automatically runs AI analysis" do
    output = run_generator ["app/models/post.rb"]

    assert_includes output, "AI suggested tests: 1"
    assert_includes output, "matches titles case-insensitively"
    assert_includes output,
      "Reason: The custom method downcases both values before matching."
  end

  test "reports AI candidate test code" do
    output = run_generator ["app/models/post.rb"]

    assert_includes output, "Candidate test:"
    assert_includes output,
      'test "title_matches finds substrings case insensitively" do'
    assert_includes output,
      'post = Post.new(title: "Hello World")'
    assert_includes output,
      'assert post.title_matches?("hello")'
  end

  test "automatically validates and rejects invalid AI test code" do
    output = run_generator ["app/models/post.rb"]

    assert_includes output, "AI test results: 1"
    assert_includes output,
      "REJECTED: matches titles case-insensitively"
    assert_includes output, "test code is not valid Ruby"
  end

  test "does not keep rejected AI test code" do
    run_generator ["app/models/post.rb"]

    path = File.join(
      destination_root,
      "test/models/post_test.rb"
    )

    source = File.read(path)

    refute_includes source,
      'test "title_matches finds substrings case insensitively" do'
  end

  test "sends source and existing tests to AI" do
    run_generator ["app/models/post.rb"]

    context = @ai_client.contexts.first

    assert_equal :model, context[:target_type]
    assert_equal "Post", context[:class_name]
    assert_includes context[:source], "def title_matches?"
    assert context.key?(:existing_tests)
    assert context.key?(:deterministic_concerns)
  end
end