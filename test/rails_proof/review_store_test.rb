require "test_helper"
require "json"
require "tmpdir"
require "rails_proof/review_store"

class RailsProof::ReviewStoreTest < ActiveSupport::TestCase
  test "persists a failing candidate for human review" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      path = store.save(
        concern: review_concern,
        test_output: "Expected false to be truthy.",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      assert path.file?
      assert_equal(
        root.join(".rails_proof/review"),
        path.dirname
      )

      record = JSON.parse(path.read)

      assert_equal 3, record["version"]
      assert_equal "needs_review", record["status"]
      assert_equal 1, record["occurrences"]
      assert_equal "contract_check", record["kind"]
      assert_equal "app/models/post.rb", record["target_path"]
      assert record["target_fingerprint"].present?
      assert record["test_fingerprint"].present?
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
      assert record["last_seen_at"].present?
    end
  end

  test "reuses the same review file for the same unresolved finding" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      first = store.save(
        concern: review_concern,
        test_output: "first failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      second = store.save(
        concern: review_concern,
        test_output: "second failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      assert_equal first, second

      review_files = root
        .join(".rails_proof/review")
        .glob("*.json")

      assert_equal 1, review_files.count

      record = JSON.parse(first.read)

      assert_equal 2, record["occurrences"]
      assert_equal "second failure", record["test_output"]
    end
  end

  test "reuses review when AI changes only the candidate test name" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      first_concern = {
        type: :ai,
        kind: :contract_check,
        name:
          "title_matches_exactly? requires a case-insensitive full-title match",
        reason: "Exact matching should reject partial titles.",
        test_code: <<~RUBY
          test "title_matches_exactly? requires a case-insensitive full-title match" do
            post = Post.new(title: "Learning Rails")

            assert post.title_matches_exactly?("learning rails")
            assert_not post.title_matches_exactly?("Rails")
          end
        RUBY
      }

      second_concern = {
        type: :ai,
        kind: :contract_check,
        name:
          "title_matches_exactly? requires the entire title to match",
        reason: "Substring matching disagrees with the method contract.",
        test_code: <<~RUBY
          test "title_matches_exactly? requires the entire title to match" do
            post = Post.new(title: "Learning Rails")

            assert post.title_matches_exactly?("learning rails")
            assert_not post.title_matches_exactly?("Rails")
          end
        RUBY
      }

      first = store.save(
        concern: first_concern,
        test_output: "first failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      second = store.save(
        concern: second_concern,
        test_output: "second failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      assert_equal first, second

      review_files = root
        .join(".rails_proof/review")
        .glob("*.json")

      assert_equal 1, review_files.count

      record = JSON.parse(first.read)

      assert_equal 2, record["occurrences"]
      assert_equal(
        "title_matches_exactly? requires the entire title to match",
        record["name"]
      )
      assert_equal "second failure", record["test_output"]
    end
  end

  test "matches repeated findings by generated test name" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      first = store.save(
        concern: review_concern,
        test_output: "first failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      renamed_concern = review_concern.merge(
        name: "different AI wording"
      )

      second = store.save(
        concern: renamed_concern,
        test_output: "second failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      assert_equal first, second
    end
  end

  test "creates a new review after the target source changes" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      first = store.save(
        concern: review_concern,
        test_output: "first failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      create_target(
        root,
        source: <<~RUBY
          class Post < ApplicationRecord
            def publish!
              update!(published_at: nil)
            end
          end
        RUBY
      )

      second = store.save(
        concern: review_concern,
        test_output: "second failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      refute_equal first, second

      review_files = root
        .join(".rails_proof/review")
        .glob("*.json")

      assert_equal 2, review_files.count
    end
  end

  test "returns only findings for the current target source" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      store.save(
        concern: review_concern,
        test_output: "failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      findings = store.outstanding_findings(
        target_path: "app/models/post.rb",
        test_file_path: "test/models/post_test.rb"
      )

      assert_equal 1, findings.count
      assert_equal(
        "publish! persists its changes",
        findings.first["name"]
      )

      create_target(
        root,
        source: <<~RUBY
          class Post < ApplicationRecord
            def publish!
              update!(published_at: Time.zone.now)
            end
          end
        RUBY
      )

      assert_empty(
        store.outstanding_findings(
          target_path: "app/models/post.rb",
          test_file_path: "test/models/post_test.rb"
        )
      )
    end
  end

  test "does not return findings belonging to another test file" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      store.save(
        concern: review_concern,
        test_output: "failure",
        test_file_path: "test/models/post_test.rb",
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      assert_empty(
        store.outstanding_findings(
          target_path: "app/models/post.rb",
          test_file_path: "test/models/article_test.rb"
        )
      )
    end
  end

  test "supports symbol or string concern keys" do
    Dir.mktmpdir do |directory|
      root = Pathname.new(directory)
      create_target(root)

      store = RailsProof::ReviewStore.new(
        root: root
      )

      path = store.save(
        concern: {
          "kind" => "coverage",
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
        test_class_name: "PostTest",
        target_path: "app/models/post.rb"
      )

      record = JSON.parse(path.read)

      assert_equal "coverage", record["kind"]
      assert_equal "string keyed concern", record["name"]
      assert_equal "Testing compatibility.", record["reason"]
      assert_includes record["test_code"], "assert true"
    end
  end

  private

  def create_target(root, source: nil)
    path = root.join("app/models/post.rb")
    path.dirname.mkpath

    path.write(
      source ||
        <<~RUBY
          class Post < ApplicationRecord
            def publish!
              update!(published_at: Time.current)
            end
          end
        RUBY
    )
  end

  def review_concern
    {
      type: :ai,
      kind: :contract_check,
      name: "publish! persists its changes",
      reason: "The method appears to update persistent state.",
      test_code: <<~RUBY
        test "publish! persists its changes" do
          post = Post.create!

          post.publish!

          assert post.reload.published?
        end
      RUBY
    }
  end
end