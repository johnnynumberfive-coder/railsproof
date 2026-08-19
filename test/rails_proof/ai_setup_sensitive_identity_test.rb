require "test_helper"
require "rails_proof/ai_test_identity"
require "rails_proof/ai_concern_filter"

class RailsProof::AiSetupSensitiveIdentityTest < ActiveSupport::TestCase
  test "same assertion with different setup is not the same behavior" do
    full_title = <<~RUBY
      test "exact matching rejects partial titles" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    nil_title = <<~RUBY
      test "exact matching handles a nil title" do
        post = Post.new(title: nil)

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    refute RailsProof::AiTestIdentity.same?(
      first_name: "exact matching rejects partial titles",
      first_test_code: full_title,
      second_name: "exact matching handles a nil title",
      second_test_code: nil_title
    )
  end

  test "same assertion with the same setup remains the same behavior" do
    broader = <<~RUBY
      test "exact matching requires full equality" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("LEARNING RAILS")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    narrower = <<~RUBY
      test "exact matching rejects partial titles" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    assert RailsProof::AiTestIdentity.same?(
      first_name: "exact matching requires full equality",
      first_test_code: broader,
      second_name: "exact matching rejects partial titles",
      second_test_code: narrower
    )
  end

  test "behavior keys include setup context" do
    full_title = <<~RUBY
      test "full title setup" do
        post = Post.new(title: "Learning Rails")

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    nil_title = <<~RUBY
      test "nil title setup" do
        post = Post.new(title: nil)

        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    refute_equal(
      RailsProof::AiTestIdentity.behavior_keys(full_title),
      RailsProof::AiTestIdentity.behavior_keys(nil_title)
    )
  end

  test "filter keeps distinct behaviors with the same assertion" do
    full_title_concern = {
      type: :ai,
      kind: :coverage,
      name: "requires whole title equality",
      reason: "Exact matching should reject partial titles.",
      test_code: <<~RUBY
        test "requires whole title equality" do
          post = Post.new(title: "Learning Rails")

          assert post.title_matches_exactly?("LEARNING RAILS")
          assert_not post.title_matches_exactly?("Rails")
        end
      RUBY
    }

    nil_title_concern = {
      type: :ai,
      kind: :coverage,
      name: "handles a nil title",
      reason: "The predicate should safely handle an unpopulated title.",
      test_code: <<~RUBY
        test "handles a nil title" do
          post = Post.new(title: nil)

          assert_not post.title_matches_exactly?("Rails")
        end
      RUBY
    }

    filter = RailsProof::AiConcernFilter.new(
      concerns: [
        full_title_concern,
        nil_title_concern
      ],
      existing_tests: "",
      review_findings: []
    )

    assert_equal 2, filter.concerns.count
    assert_empty filter.skipped
  end

  test "filter still dedupes a narrower restatement with identical setup" do
    broader_concern = {
      type: :ai,
      kind: :contract_check,
      name: "requires whole title equality",
      reason: "Exact matching should reject partial titles.",
      test_code: <<~RUBY
        test "requires whole title equality" do
          post = Post.new(title: "Learning Rails")

          assert post.title_matches_exactly?("LEARNING RAILS")
          assert_not post.title_matches_exactly?("Rails")
        end
      RUBY
    }

    narrower_concern = {
      type: :ai,
      kind: :contract_check,
      name: "rejects partial title matches",
      reason: "Partial matching violates exact-match semantics.",
      test_code: <<~RUBY
        test "rejects partial title matches" do
          post = Post.new(title: "Learning Rails")

          assert_not post.title_matches_exactly?("Rails")
        end
      RUBY
    }

    filter = RailsProof::AiConcernFilter.new(
      concerns: [
        narrower_concern
      ],
      existing_tests: "",
      review_findings: [
        {
          "name" => broader_concern[:name],
          "test_code" => broader_concern[:test_code]
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
end