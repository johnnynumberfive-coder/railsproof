require "test_helper"
require "rails_proof/ai_test_identity"
require "rails_proof/ai_concern_filter"

class RailsProof::AiReviewDedupeRegressionTest < ActiveSupport::TestCase
  test "recognizes a narrower candidate as the same reviewed behavior" do
    assert RailsProof::AiTestIdentity.same?(
      first_name:
        "title_matches_exactly? requires a case-insensitive full-title match",
      first_test_code: broader_candidate,
      second_name:
        "title_matches_exactly? rejects partial title matches",
      second_test_code: narrower_candidate
    )
  end

  test "recognizes the same reviewed behavior in either comparison direction" do
    assert RailsProof::AiTestIdentity.same?(
      first_name:
        "title_matches_exactly? rejects partial title matches",
      first_test_code: narrower_candidate,
      second_name:
        "title_matches_exactly? requires the entire title to match",
      second_test_code: broader_candidate
    )
  end

  test "does not merge tests that merely share one assertion" do
    first = <<~RUBY
      test "first behavior" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("learning rails")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    second = <<~RUBY
      test "different behavior" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
        assert_not post.title_matches_exactly?(nil)
      end
    RUBY

    refute RailsProof::AiTestIdentity.same?(
      first_name: "first behavior",
      first_test_code: first,
      second_name: "different behavior",
      second_test_code: second
    )
  end

  test "does not use trivial assertions as behavioral identity" do
    refute RailsProof::AiTestIdentity.same?(
      first_name: "first trivial test",
      first_test_code: <<~RUBY,
        test "first trivial test" do
          assert true
        end
      RUBY
      second_name: "second trivial test",
      second_test_code: <<~RUBY
        test "second trivial test" do
          assert true
        end
      RUBY
    )
  end

  test "filter skips narrower candidate already represented by review" do
    filter = RailsProof::AiConcernFilter.new(
      concerns: [
        {
          type: :ai,
          kind: :contract_check,
          name:
            "title_matches_exactly? rejects partial title matches",
          reason:
            "Partial matching disagrees with the exact-match contract.",
          test_code: narrower_candidate
        }
      ],
      existing_tests: "",
      review_findings: [
        {
          "version" => 2,
          "status" => "needs_review",
          "name" =>
            "title_matches_exactly? requires a case-insensitive full-title match",
          "test_code" => broader_candidate
        }
      ]
    )

    assert_empty filter.concerns
    assert_equal 1, filter.skipped.count
    assert_equal(
      :needs_review,
      filter.skipped.first.reason
    )
  end

  private

  def broader_candidate
    <<~RUBY
      test "title_matches_exactly? requires a case-insensitive full-title match" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("learning rails")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY
  end

  def narrower_candidate
    <<~RUBY
      test "title_matches_exactly? rejects partial title matches" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY
  end
end