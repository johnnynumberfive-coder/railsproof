require "test_helper"
require "fileutils"
require "tmpdir"
require "rails_proof/test_runner"

class RailsProof::TestRunnerUnavailableApiTest <
  ActiveSupport::TestCase

  test "rejects stub when the target test environment does not provide it" do
    with_fake_app(
      <<~OUTPUT
        Error:
        PostTest#test_something:
        NoMethodError: undefined method 'stub' for an instance of Post
      OUTPUT
    ) do |root|
      runner = RailsProof::TestRunner.new(
        root: root,
        test_file_path: "test/models/post_test.rb"
      )

      error = assert_raises RailsProof::TestRunner::Error do
        runner.run
      end

      assert_includes error.message, ".stub is unavailable"
    end
  end

  test "rejects Minitest Mock when the target test environment does not provide it" do
    with_fake_app(
      <<~OUTPUT
        Error:
        PostTest#test_something:
        NameError: uninitialized constant Minitest::Mock
      OUTPUT
    ) do |root|
      runner = RailsProof::TestRunner.new(
        root: root,
        test_file_path: "test/models/post_test.rb"
      )

      error = assert_raises RailsProof::TestRunner::Error do
        runner.run
      end

      assert_includes error.message, "Minitest::Mock is unavailable"
    end
  end

  test "does not treat an ordinary NoMethodError as an unavailable test API" do
    with_fake_app(
      <<~OUTPUT
        Error:
        PostTest#test_something:
        NoMethodError: undefined method 'calculate_total' for nil
      OUTPUT
    ) do |root|
      runner = RailsProof::TestRunner.new(
        root: root,
        test_file_path: "test/models/post_test.rb"
      )

      result = runner.run

      refute result.passed?
      assert_includes result.output, "calculate_total"
    end
  end

  private

  def with_fake_app(output)
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)

      FileUtils.mkdir_p(root.join("bin"))
      FileUtils.mkdir_p(root.join("test/models"))

      root.join("test/test_helper.rb").write("")
      root.join("test/models/post_test.rb").write("")

      root.join("bin/rails").write(
        <<~RUBY
          #!/usr/bin/env ruby

          warn #{output.inspect}
          exit 1
        RUBY
      )

      FileUtils.chmod("+x", root.join("bin/rails"))

      yield root
    end
  end
end