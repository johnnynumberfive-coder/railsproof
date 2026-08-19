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

  setup do
    FakeRunner.results = []
  end

  test "keeps a candidate when its test passes" do
    with_test_app do |root|
      create_existing_test_file(root)

      FakeRunner.results = [
        passing_result
      ]

      executor = build_executor(
        root: root,
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

      source = test_file(root).read

      assert_includes source,
        'test "matches case insensitively" do'
      assert_includes source,
        'assert post.title_matches?("hello")'
    end
  end

  test "rolls back a candidate when its test fails" do
    with_test_app do |root|
      create_existing_test_file(root)

      before = test_file(root).read

      FakeRunner.results = [
        failing_result
      ]

      executor = build_executor(
        root: root,
        concerns: [
          valid_concern(
            name: "bad test",
            assertion: "assert false"
          )
        ]
      )

      results = executor.execute

      assert_equal 1, results.count
      assert results.first.rejected?
      assert_equal before, test_file(root).read
      assert_includes results.first.errors, "generated test failed"
      assert_includes results.first.test_output, "failure output"
    end
  end

  test "rejects invalid AI code without modifying the file" do
    with_test_app do |root|
      create_existing_test_file(root)

      before = test_file(root).read

      executor = build_executor(
        root: root,
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
      assert_equal before, test_file(root).read
      assert_includes(
        results.first.errors,
        "test code is not valid Ruby"
      )
    end
  end

  test "keeps passing candidates and rolls back only a later failing candidate" do
    with_test_app do |root|
      create_existing_test_file(root)

      FakeRunner.results = [
        passing_result,
        failing_result
      ]

      executor = build_executor(
        root: root,
        concerns: [
          valid_concern(
            name: "good behavior",
            assertion: "assert true"
          ),
          valid_concern(
            name: "bad behavior",
            assertion: "assert false"
          )
        ]
      )

      results = executor.execute

      assert results[0].kept?
      assert results[1].rejected?

      source = test_file(root).read

      assert_includes source, 'test "good behavior" do'
      refute_includes source, 'test "bad behavior" do'
    end
  end

  test "creates a missing test file when a candidate passes" do
    with_test_app do |root|
      FakeRunner.results = [
        passing_result
      ]

      executor = build_executor(
        root: root,
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

      executor = build_executor(
        root: root,
        concerns: [
          valid_concern(
            name: "bad new behavior",
            assertion: "assert false"
          )
        ]
      )

      results = executor.execute

      assert results.first.rejected?
      refute test_file(root).exist?
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

  def build_executor(root:, concerns:)
    RailsProof::AiTestExecutor.new(
      root: root,
      test_file_path: "test/models/post_test.rb",
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: concerns,
      runner_class: FakeRunner
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