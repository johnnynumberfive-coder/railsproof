require "test_helper"
require "rails_proof/ai_concern_filter"

class RailsProof::AiConcernFilterTest < ActiveSupport::TestCase
  test "keeps a new AI concern" do
    filter = build_filter(
      concerns: [
        concern(
          name: "publish! persists its change"
        )
      ]
    )

    assert_equal 1, filter.concerns.count
    assert_empty filter.skipped
  end

  test "skips a concern whose name matches an existing test" do
    filter = build_filter(
      existing_tests: <<~RUBY,
        class PostTest < ActiveSupport::TestCase
          test "publish! persists its change" do
            assert true
          end
        end
      RUBY
      concerns: [
        concern(
          name: "publish! persists its change"
        )
      ]
    )

    assert_empty filter.concerns
    assert_equal 1, filter.skipped.count
    assert_equal(
      :existing_test,
      filter.skipped.first.reason
    )
  end

  test "skips when generated test name matches existing test even if concern name differs" do
    filter = build_filter(
      existing_tests: <<~RUBY,
        class PostTest < ActiveSupport::TestCase
          test "publish! persists its change" do
            assert true
          end
        end
      RUBY
      concerns: [
        concern(
          name: "publication is durable",
          test_name: "publish! persists its change"
        )
      ]
    )

    assert_empty filter.concerns
    assert_equal(
      :existing_test,
      filter.skipped.first.reason
    )
  end

  test "normalizes punctuation spacing and case when comparing test names" do
    filter = build_filter(
      existing_tests: <<~RUBY,
        class PostTest < ActiveSupport::TestCase
          test "title_matches_exactly? rejects partial title matches" do
            assert true
          end
        end
      RUBY
      concerns: [
        concern(
          name: "TITLE MATCHES EXACTLY rejects partial title matches"
        )
      ]
    )

    assert_empty filter.concerns
    assert_equal(
      :existing_test,
      filter.skipped.first.reason
    )
  end

  test "skips a finding already waiting for human review" do
    filter = build_filter(
      review_findings: [
        {
          "name" =>
            "title_matches_exactly? rejects partial title matches",
          "test_code" => <<~RUBY
            test "title_matches_exactly? rejects partial title matches" do
              assert false
            end
          RUBY
        }
      ],
      concerns: [
        concern(
          name:
            "title_matches_exactly? rejects partial title matches"
        )
      ]
    )

    assert_empty filter.concerns
    assert_equal 1, filter.skipped.count
    assert_equal(
      :needs_review,
      filter.skipped.first.reason
    )
  end

  test "matches review finding when AI renames the same candidate test" do
    review_code = <<~RUBY
      test "title_matches_exactly? requires a case-insensitive full-title match" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("learning rails")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    second_code = <<~RUBY
      test "title_matches_exactly? requires the entire title to match" do
        post = Post.new(title: "Learning Rails")

        assert post.title_matches_exactly?("learning rails")
        assert_not post.title_matches_exactly?("Rails")
      end
    RUBY

    filter = build_filter(
      review_findings: [
        {
          "name" =>
            "title_matches_exactly? requires a case-insensitive full-title match",
          "test_code" => review_code
        }
      ],
      concerns: [
        {
          type: :ai,
          kind: :contract_check,
          name:
            "title_matches_exactly? requires the entire title to match",
          reason: "The implementation permits partial matches.",
          test_code: second_code
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

  test "matches review findings by generated test declaration" do
    filter = build_filter(
      review_findings: [
        {
          "name" => "possible exact match bug",
          "test_code" => <<~RUBY
            test "exact matching rejects partial titles" do
              assert false
            end
          RUBY
        }
      ],
      concerns: [
        concern(
          name: "different AI wording",
          test_name: "exact matching rejects partial titles"
        )
      ]
    )

    assert_empty filter.concerns
    assert_equal(
      :needs_review,
      filter.skipped.first.reason
    )
  end

  test "skips duplicate suggestions from the same AI response" do
    filter = build_filter(
      concerns: [
        concern(
          name: "publish! persists its change"
        ),
        concern(
          name: "publish! persists its change"
        )
      ]
    )

    assert_equal 1, filter.concerns.count
    assert_equal 1, filter.skipped.count
    assert_equal(
      :duplicate_suggestion,
      filter.skipped.first.reason
    )
  end

  test "skips same-run duplicate when AI changes only the test name" do
    first = concern(
      name: "requires a case-insensitive full-title match",
      test_name: "requires a case-insensitive full-title match"
    )

    second = concern(
      name: "requires the entire title to match",
      test_name: "requires the entire title to match"
    )

    second[:test_code] = first[:test_code].sub(
      "requires a case-insensitive full-title match",
      "requires the entire title to match"
    )

    filter = build_filter(
      concerns: [
        first,
        second
      ]
    )

    assert_equal 1, filter.concerns.count
    assert_equal 1, filter.skipped.count
    assert_equal(
      :duplicate_suggestion,
      filter.skipped.first.reason
    )
  end

  test "does not let an invalid first suggestion suppress a later valid duplicate" do
    invalid = {
      type: :ai,
      kind: :coverage,
      name: "publish! persists its change",
      reason: "Worth testing.",
      test_code: <<~RUBY
        test "publish! persists its change" do
          assert true
      RUBY
    }

    valid = concern(
      name: "publish! persists its change"
    )

    filter = build_filter(
      concerns: [
        invalid,
        valid
      ]
    )

    assert_equal 2, filter.concerns.count
    assert_empty filter.skipped
  end

  test "keeps unrelated concerns" do
    filter = build_filter(
      existing_tests: <<~RUBY,
        class PostTest < ActiveSupport::TestCase
          test "belongs to user" do
            assert true
          end
        end
      RUBY
      review_findings: [
        {
          "name" => "publish! persists its change",
          "test_code" => <<~RUBY
            test "publish! persists its change" do
              assert false
            end
          RUBY
        }
      ],
      concerns: [
        concern(
          name: "archive! records archived_at"
        )
      ]
    )

    assert_equal 1, filter.concerns.count
    assert_empty filter.skipped
  end

  private

  def build_filter(
    concerns:,
    existing_tests: "",
    review_findings: []
  )
    RailsProof::AiConcernFilter.new(
      concerns: concerns,
      existing_tests: existing_tests,
      review_findings: review_findings
    )
  end

  def concern(name:, test_name: nil)
    test_name ||= name

    {
      type: :ai,
      kind: :coverage,
      name: name,
      reason: "The behavior deserves coverage.",
      test_code: <<~RUBY
        test "#{test_name}" do
          assert true
        end
      RUBY
    }
  end
end