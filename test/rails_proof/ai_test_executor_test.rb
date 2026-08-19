require "test_helper"
require "tmpdir"
require "rails_proof/ai_test_executor"

class RailsProof::AiTestExecutorTest < ActiveSupport::TestCase
  FakeRunResult = Struct.new(
    :passed,
    :output,
    keyword_init: true
  ) do
    def passed?
      passed
    end
  end

  class FakeRunner
    class << self
      attr_accessor :results
    end

    def initialize(root:, test_file_path:)
      @root = root
      @test_file_path = test_file_path
    end

    def run
      self.class.results.shift
    end
  end

  class FakeReviewStore
    attr_reader :reviews

    def initialize
      @reviews = []
    end

    def save(**review)
      reviews << review

      Pathname.new(
        "/fake/reviews/review-#{reviews.count}.json"
      )
    end
  end

  setup do
    FakeRunner.results = []
  end

  test "keeps a candidate when its test passes" do
    with_test_app do |root|
      create_existing_test_file(root)

      FakeRunner.results = [
        passing_result
      ]

      review_store = FakeReviewStore.new

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          valid_concern(
            name: "matches case insensitively",
            assertion: 'assert post.title_matches?("hello")'
          )
        ]
      )

      results = executor.execute

      assert_equal 1, results.count
      assert results.first.kept?
      refute results.first.needs_review?
      refute results.first.rejected?
      assert_nil results.first.review_path
      assert_empty review_store.reviews

      source = test_file(root).read

      assert_includes source,
        'test "matches case insensitively" do'
      assert_includes source,
        'assert post.title_matches?("hello")'
    end
  end

  test "marks a valid failing candidate as needing review" do
    with_test_app do |root|
      create_existing_test_file(root)

      before = test_file(root).read

      FakeRunner.results = [
        failing_result
      ]

      review_store = FakeReviewStore.new

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          valid_concern(
            name: "possible application bug",
            assertion: "assert false"
          )
        ]
      )

      results = executor.execute
      result = results.first

      assert_equal 1, results.count
      assert result.needs_review?
      refute result.rejected?
      refute result.kept?

      assert_equal before, test_file(root).read

      assert_includes(
        result.errors,
        "candidate test failed against application"
      )

      assert_includes result.test_output, "failure output"

      assert_equal(
        Pathname.new("/fake/reviews/review-1.json"),
        result.review_path
      )

      assert_equal 1, review_store.reviews.count
    end
  end

  test "persists the concern and failure output for review" do
    with_test_app do |root|
      create_existing_test_file(root)

      FakeRunner.results = [
        failing_result
      ]

      review_store = FakeReviewStore.new

      concern = valid_concern(
        name: "possible application bug",
        assertion: "assert false"
      )

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [concern]
      )

      executor.execute

      review = review_store.reviews.first

      assert_equal concern, review[:concern]
      assert_equal failing_result.output, review[:test_output]
      assert_equal(
        "app/models/post.rb",
        review[:target_path]
      )
      assert_equal(
        "test/models/post_test.rb",
        review[:test_file_path]
      )
      assert_equal "PostTest", review[:test_class_name]
    end
  end

  test "rejects invalid AI code without storing it for review" do
    with_test_app do |root|
      create_existing_test_file(root)

      before = test_file(root).read
      review_store = FakeReviewStore.new

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          {
            type: :ai,
            name: "broken",
            reason: "Testing validation.",
            test_code: <<~RUBY
              test "broken" do
                assert true
            RUBY
          }
        ]
      )

      results = executor.execute

      assert results.first.rejected?
      refute results.first.needs_review?
      assert_equal before, test_file(root).read
      assert_empty review_store.reviews

      assert_includes(
        results.first.errors,
        "test code is not valid Ruby"
      )
    end
  end

  test "keeps passing candidates and flags only a later failing candidate" do
    with_test_app do |root|
      create_existing_test_file(root)

      FakeRunner.results = [
        passing_result,
        failing_result
      ]

      review_store = FakeReviewStore.new

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          valid_concern(
            name: "good behavior",
            assertion: "assert true"
          ),
          valid_concern(
            name: "possible bug",
            assertion: "assert false"
          )
        ]
      )

      results = executor.execute

      assert results[0].kept?
      assert results[1].needs_review?

      source = test_file(root).read

      assert_includes source, 'test "good behavior" do'
      refute_includes source, 'test "possible bug" do'

      assert_equal 1, review_store.reviews.count
    end
  end

  test "creates a missing test file when a candidate passes" do
    with_test_app do |root|
      FakeRunner.results = [
        passing_result
      ]

      review_store = FakeReviewStore.new

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          valid_concern(
            name: "new behavior",
            assertion: "assert true"
          )
        ]
      )

      results = executor.execute

      assert results.first.kept?
      assert test_file(root).file?
      assert_empty review_store.reviews

      source = test_file(root).read

      assert_includes source, 'require "test_helper"'
      assert_includes source,
        "class PostTest < ActiveSupport::TestCase"
      assert_includes source, 'test "new behavior" do'
    end
  end

  test "removes a newly created test file when its candidate fails" do
    with_test_app do |root|
      FakeRunner.results = [
        failing_result
      ]

      review_store = FakeReviewStore.new

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          valid_concern(
            name: "possible bug in new target",
            assertion: "assert false"
          )
        ]
      )

      results = executor.execute

      assert results.first.needs_review?
      refute results.first.rejected?
      refute test_file(root).exist?
      assert_equal 1, review_store.reviews.count
    end
  end

  test "keeps needs review status when review persistence fails" do
    with_test_app do |root|
      create_existing_test_file(root)

      FakeRunner.results = [
        failing_result
      ]

      review_store = Object.new

      def review_store.save(**)
        raise "disk is full"
      end

      executor = build_executor(
        root: root,
        review_store: review_store,
        concerns: [
          valid_concern(
            name: "possible application bug",
            assertion: "assert false"
          )
        ]
      )

      result = executor.execute.first

      assert result.needs_review?
      assert_nil result.review_path

      assert_includes(
        result.errors,
        "RailsProof could not persist review: disk is full"
      )
    end
  end

  private

  def with_test_app
    Dir.mktmpdir do |directory|
      yield Pathname.new(directory)
    end
  end

  def test_file(root)
    root.join("test/models/post_test.rb")
  end

  def create_existing_test_file(root)
    path = test_file(root)
    path.dirname.mkpath

    path.write(
      <<~RUBY
        require "test_helper"

        class PostTest < ActiveSupport::TestCase
          test "existing behavior" do
            assert true
          end
        end
      RUBY
    )
  end

  def build_executor(
    root:,
    concerns:,
    review_store:
  )
    RailsProof::AiTestExecutor.new(
      root: root,
      target_path: "app/models/post.rb",
      test_file_path: "test/models/post_test.rb",
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: concerns,
      runner_class: FakeRunner,
      review_store: review_store
    )
  end

  def valid_concern(name:, assertion:)
    {
      type: :ai,
      name: name,
      reason: "The source contains behavior worth testing.",
      test_code: <<~RUBY
        test "#{name}" do
          post = Post.new(title: "Hello World")

          #{assertion}
        end
      RUBY
    }
  end

  def passing_result
    FakeRunResult.new(
      passed: true,
      output: "1 runs, 1 assertions, 0 failures, 0 errors"
    )
  end

  def failing_result
    FakeRunResult.new(
      passed: false,
      output: "1 runs, 1 assertions, 1 failures, 0 errors\nfailure output"
    )
  end
end