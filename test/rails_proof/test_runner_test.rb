require "test_helper"
require "fileutils"
require "tmpdir"
require "rails_proof/test_runner"

class RailsProof::TestRunnerTest < ActiveSupport::TestCase
  test "uses bin/rails test in a normal Rails application" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)

      create_file root.join("bin/rails")
      create_file root.join("test/test_helper.rb")
      create_file root.join("test/models/post_test.rb")

      runner = RailsProof::TestRunner.new(
        root: root,
        test_file_path: "test/models/post_test.rb"
      )

      assert_equal root, runner.working_directory

      assert_equal(
        [
          root.join("bin/rails").to_s,
          "test",
          "test/models/post_test.rb"
        ],
        runner.command
      )
    end
  end

  test "uses an ancestor bin/test for a plugin dummy application" do
    Dir.mktmpdir do |directory|
      plugin_root = Pathname.new(directory)
      dummy_root = plugin_root.join("test/dummy")

      create_file plugin_root.join("bin/test")
      create_file plugin_root.join("test/test_helper.rb")
      create_file dummy_root.join("bin/rails")
      create_file dummy_root.join("test/models/post_test.rb")

      runner = RailsProof::TestRunner.new(
        root: dummy_root,
        test_file_path: "test/models/post_test.rb"
      )

      assert_equal plugin_root, runner.working_directory

      assert_equal(
        [
          plugin_root.join("bin/test").to_s,
          "test/dummy/test/models/post_test.rb"
        ],
        runner.command
      )
    end
  end

  test "prefers the Rails application runner when test_helper exists" do
    Dir.mktmpdir do |directory|
      plugin_root = Pathname.new(directory)
      app_root = plugin_root.join("example_app")

      create_file plugin_root.join("bin/test")
      create_file plugin_root.join("test/test_helper.rb")

      create_file app_root.join("bin/rails")
      create_file app_root.join("test/test_helper.rb")
      create_file app_root.join("test/models/post_test.rb")

      runner = RailsProof::TestRunner.new(
        root: app_root,
        test_file_path: "test/models/post_test.rb"
      )

      assert_equal app_root, runner.working_directory

      assert_equal(
        [
          app_root.join("bin/rails").to_s,
          "test",
          "test/models/post_test.rb"
        ],
        runner.command
      )
    end
  end

  test "raises when no test runner can be found" do
    Dir.mktmpdir do |directory|
      runner = RailsProof::TestRunner.new(
        root: directory,
        test_file_path: "test/models/post_test.rb"
      )

      assert_raises RailsProof::TestRunner::Error do
        runner.command
      end
    end
  end

  private

  def create_file(path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "")
  end
end