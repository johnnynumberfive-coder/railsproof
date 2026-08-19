require "test_helper"
require "json"
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
    refute_includes output, "NEEDS REVIEW:"
    refute_includes output, "SKIPPED:"
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

  test "marks a valid failing AI test as needing review" do
    use_valid_failing_suggestion
    create_failing_rails_runner

    output = run_generator ["app/models/post.rb"]

    assert_includes output, "AI test results: 1"
    assert_includes output,
      "NEEDS REVIEW: possible application bug"
    assert_includes output,
      "candidate test failed against application"
    assert_includes output,
      "Review saved: .rails_proof/review/"
    assert_includes output, "Test output:"
    assert_includes output, "failure output"

    refute_includes output,
      "REJECTED: possible application bug"
  end

  test "rolls a failing AI test out of the live test suite" do
    use_valid_failing_suggestion
    create_failing_rails_runner

    run_generator ["app/models/post.rb"]

    path = File.join(
      destination_root,
      "test/models/post_test.rb"
    )

    source = File.read(path)

    refute_includes source,
      'test "possible application bug" do'
  end

  test "persists a failing AI test for human review" do
    use_valid_failing_suggestion
    create_failing_rails_runner

    run_generator ["app/models/post.rb"]

    review_files = review_files_for_destination

    assert_equal 1, review_files.count

    record = JSON.parse(
      File.read(review_files.first)
    )

    assert_equal "needs_review", record["status"]
    assert_equal "app/models/post.rb", record["target_path"]
    assert_equal(
      "test/models/post_test.rb",
      record["test_file_path"]
    )
    assert_equal "PostTest", record["test_class_name"]
    assert_equal(
      "possible application bug",
      record["name"]
    )
    assert_equal(
      "The candidate disagrees with application behavior.",
      record["reason"]
    )
    assert_includes(
      record["test_code"],
      'test "possible application bug" do'
    )
    assert_includes record["test_output"], "failure output"
  end

  test "skips a finding already awaiting human review" do
    use_valid_failing_suggestion
    create_failing_rails_runner

    first_output = run_generator ["app/models/post.rb"]

    assert_includes first_output,
      "NEEDS REVIEW: possible application bug"

    assert_equal 1, review_files_for_destination.count

    second_output = run_generator ["app/models/post.rb"]

    assert_includes second_output,
      "SKIPPED: possible application bug"
    assert_includes second_output,
      "already awaiting human review"

    refute_includes second_output,
      "NEEDS REVIEW: possible application bug"

    assert_equal 1, review_files_for_destination.count
  end

  test "skips duplicate suggestions from the same AI response" do
    @ai_client.suggestions = [
      valid_passing_suggestion,
      valid_passing_suggestion
    ]

    create_passing_rails_runner

    output = run_generator ["app/models/post.rb"]

    assert_includes output, "AI suggested tests: 2"
    assert_includes output,
      "KEPT: new custom behavior"
    assert_includes output,
      "SKIPPED: new custom behavior"
    assert_includes output,
      "duplicate AI suggestion"

    path = File.join(
      destination_root,
      "test/models/post_test.rb"
    )

    source = File.read(path)

    assert_equal(
      1,
      source.scan('test "new custom behavior" do').count
    )
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

  private

  def use_valid_failing_suggestion
    @ai_client.suggestions = [
      {
        kind: "contract_check",
        name: "possible application bug",
        reason: "The candidate disagrees with application behavior.",
        test_code: <<~RUBY
          test "possible application bug" do
            assert false
          end
        RUBY
      }
    ]
  end

  def valid_passing_suggestion
    {
      kind: "coverage",
      name: "new custom behavior",
      reason: "The behavior deserves coverage.",
      test_code: <<~RUBY
        test "new custom behavior" do
          assert true
        end
      RUBY
    }
  end

  def review_files_for_destination
    Dir[
      File.join(
        destination_root,
        ".rails_proof/review/*.json"
      )
    ]
  end

  def create_failing_rails_runner
    create_rails_runner(
      exit_status: 1,
      output: <<~TEXT
        1 runs, 1 assertions, 1 failures, 0 errors
        failure output
      TEXT
    )
  end

  def create_passing_rails_runner
    create_rails_runner(
      exit_status: 0,
      output: <<~TEXT
        1 runs, 1 assertions, 0 failures, 0 errors
      TEXT
    )
  end

  def create_rails_runner(exit_status:, output:)
    bin_directory = File.join(
      destination_root,
      "bin"
    )

    test_directory = File.join(
      destination_root,
      "test"
    )

    mkdir_p bin_directory
    mkdir_p test_directory

    runner_path = File.join(
      bin_directory,
      "rails"
    )

    File.write(
      runner_path,
      <<~RUBY
        #!/usr/bin/env ruby

        puts #{output.inspect}

        exit #{exit_status}
      RUBY
    )

    File.chmod(0o755, runner_path)

    File.write(
      File.join(test_directory, "test_helper.rb"),
      ""
    )
  end
end