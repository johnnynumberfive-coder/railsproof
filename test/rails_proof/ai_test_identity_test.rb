require "test_helper"
require "rails_proof/ai_test_identity"

class RailsProof::AiTestIdentityTest < ActiveSupport::TestCase
  test "normalizes human-readable test names" do
    assert_equal(
      "title matches exactly rejects partial matches",
      RailsProof::AiTestIdentity.normalize_name(
        "TITLE_MATCHES_EXACTLY? rejects partial matches"
      )
    )
  end

  test "produces the same fingerprint when only the test name changes" do
    first = <<~RUBY
      test "title_matches_exactly? requires a case-insensitive full-title match" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("learning rails")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    second = <<~RUBY
      test "title_matches_exactly? requires the entire title to match" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("learning rails")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    assert_equal(
      RailsProof::AiTestIdentity.test_fingerprint(first),
      RailsProof::AiTestIdentity.test_fingerprint(second)
    )
  end

  test "ignores formatting differences when fingerprinting test code" do
    first = <<~RUBY
      test "checks behavior" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    second = <<~RUBY
      test "different wording" do

        post = Post.new(title: "Learning Rails")
        assert_not post.title_matches_exactly?("Rails")

      end
    RUBY

    assert_equal(
      RailsProof::AiTestIdentity.test_fingerprint(first),
      RailsProof::AiTestIdentity.test_fingerprint(second)
    )
  end

  test "produces different fingerprints for different behavior" do
    first = <<~RUBY
      test "checks exact matching" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    second = <<~RUBY
      test "checks blank queries" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?(nil)
      end
    RUBY

    refute_equal(
      RailsProof::AiTestIdentity.test_fingerprint(first),
      RailsProof::AiTestIdentity.test_fingerprint(second)
    )
  end

  test "matches concerns whose names are the same" do
    assert RailsProof::AiTestIdentity.same?(
      first_name: "publish! persists changes",
      first_test_code: <<~RUBY,
        test "one wording" do
          assert true
        end
      RUBY
      second_name: "publish! persists changes",
      second_test_code: <<~RUBY
        test "another wording" do
          assert false
        end
      RUBY
    )
  end

  test "matches concerns whose test bodies are the same despite different names" do
    first = <<~RUBY
      test "first description" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    second = <<~RUBY
      test "second description" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    assert RailsProof::AiTestIdentity.same?(
      first_name: "first AI concern",
      first_test_code: first,
      second_name: "second AI concern",
      second_test_code: second
    )
  end

  test "does not match genuinely different concerns" do
    refute RailsProof::AiTestIdentity.same?(
      first_name: "exact matching rejects partial titles",
      first_test_code: <<~RUBY,
        test "exact matching rejects partial titles" do
          assert_not post.title_matches_exactly?("Rails")
        end
      RUBY
      second_name: "blank queries do not match",
      second_test_code: <<~RUBY
        test "blank queries do not match" do
          assert_not post.title_matches_exactly?(nil)
        end
      RUBY
    )
  end

  test "returns nil fingerprint for missing test code" do
    assert_nil RailsProof::AiTestIdentity.test_fingerprint(nil)
    assert_nil RailsProof::AiTestIdentity.test_fingerprint("")
    assert_nil RailsProof::AiTestIdentity.test_fingerprint("   ")
  end
end