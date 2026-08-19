require "test_helper"
require "json"
require "tmpdir"
require "rails_proof/review_store"

class RailsProof::ReviewStoreTest < ActiveSupport::TestCase
  test "persists a failing candidate for human review" do
    Dir.mktmpdir do |directory|
      store = RailsProof::ReviewStore.new(
        root: directory
      )

      path = store.save(
        concern: {
          type: :ai,
          name: "publish! persists its changes",
          reason: "The method appears to update persistent state.",
          test_code: <<~RUBY
            test "publish! persists its changes" do
              post = Post.create!

              post.publish!

              assert post.reload.published?
            end
          RUBY
        },
        test_output: "Expected false to be truthy.",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      assert path.file?
      assert_equal(
        Pathname.new(directory).join(".rails_proof/review"),
        path.dirname
      )

      record = JSON.parse(path.read)

      assert_equal 1, record["version"]
      assert_equal "needs_review", record["status"]
      assert_equal "app/models/post.rb", record["target_path"]
      assert_equal(
        "test/models/post_test.rb",
        record["test_file_path"]
      )
      assert_equal "PostTest", record["test_class_name"]
      assert_equal(
        "publish! persists its changes",
        record["name"]
      )
      assert_equal(
        "The method appears to update persistent state.",
        record["reason"]
      )
      assert_includes(
        record["test_code"],
        'test "publish! persists its changes" do'
      )
      assert_equal(
        "Expected false to be truthy.",
        record["test_output"]
      )
      assert record["created_at"].present?
    end
  end

  test "creates unique review files for repeated findings" do
    Dir.mktmpdir do |directory|
      store = RailsProof::ReviewStore.new(
        root: directory
      )

      concern = {
        type: :ai,
        name: "possible application bug",
        reason: "Application and candidate disagree.",
        test_code: <<~RUBY
          test "possible application bug" do
            assert false
          end
        RUBY
      }

      first = store.save(
        concern: concern,
        test_output: "first failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest"
      )

      second = store.save(
        concern: concern,
        test_output: "second failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest"
      )

      refute_equal first, second
      assert first.file?
      assert second.file?
    end
  end

  test "supports symbol or string concern keys" do
    Dir.mktmpdir do |directory|
      store = RailsProof::ReviewStore.new(
        root: directory
      )

      path = store.save(
        concern: {
          "name" => "string keyed concern",
          "reason" => "Testing compatibility.",
          "test_code" => <<~RUBY
            test "string keyed concern" do
              assert true
            end
          RUBY
        },
        test_output: "failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest"
      )

      record = JSON.parse(path.read)

      assert_equal "string keyed concern", record["name"]
      assert_equal "Testing compatibility.", record["reason"]
      assert_includes record["test_code"], "assert true"
    end
  end
end