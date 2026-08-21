require "test_helper"
require "tmpdir"
require "rails_proof/ai_test_executor"

class RailsProof::AiTestExecutorNamespacedTest < ActiveSupport::TestCase
  FakeRunResult = Struct.new(
    :passed,
    :output,
    keyword_init: true
  ) do
    def passed?
      passed
    end
  end

  class PassingRunner
    def initialize(root:, test_file_path:)
      @root = root
      @test_file_path = test_file_path
    end

    def run
      FakeRunResult.new(
        passed: true,
        output: "1 runs, 1 assertions, 0 failures, 0 errors"
      )
    end
  end

  class EmptyReviewStore
    def outstanding_findings(
      target_path:,
      test_file_path:
    )
      []
    end

    def save(**)
      raise "review should not be saved for a passing test"
    end
  end

  test "adds AI tests inside a namespaced test class" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      path = root.join("test/models/post_test.rb")

      path.dirname.mkpath

      path.write(
        <<~RUBY
          require "test_helper"

          module Example
            class PostTest < ActiveSupport::TestCase
            end
          end
        RUBY
      )

      executor = RailsProof::AiTestExecutor.new(
        root: root,
        target_path: "app/models/post.rb",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "Example::PostTest",
        superclass: "ActiveSupport::TestCase",
        concerns: [
          {
            type: :ai,
            kind: :coverage,
            name: "new behavior",
            reason: "The behavior deserves coverage.",
            test_code: <<~RUBY
              test "new behavior" do
                assert true
              end
            RUBY
          }
        ],
        runner_class: PassingRunner,
        review_store: EmptyReviewStore.new
      )

      results = executor.execute

      assert_equal 1, results.count
      assert results.first.kept?

      source = path.read

      class_match = source.match(
        /
          \A.*?
          ^\s{2}class\ PostTest\ <\ ActiveSupport::TestCase\n
          (?<body>.*?)
          ^\s{2}end\s*$
        /mx
      )

      assert_not_nil class_match

      assert_includes(
        class_match[:body],
        'test "new behavior" do'
      )
    end
  end
end