require "test_helper"
require "rails_proof/model_inspector"
require "rails_proof/model_test_plan"
require "rails_proof/test_inspector"
require "rails_proof/test_coverage_plan"

class RailsProof::TestCoveragePlanTest < ActiveSupport::TestCase
  test "reports all concerns missing when the test file is empty" do
    coverage = coverage_for(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
      end
    RUBY

    assert_equal 0, coverage.covered_count
    assert_equal 2, coverage.missing_count

    assert_equal(
      [
        "belongs_to :user",
        "validates presence of title"
      ],
      coverage.missing_concerns.map { |concern| concern[:description] }
    )
  end

  test "recognizes a covered association" do
    coverage = coverage_for(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        test "belongs to user" do
          assert true
        end
      end
    RUBY

    assert_equal 1, coverage.covered_count
    assert_equal 1, coverage.missing_count

    assert_equal(
      ["belongs_to :user"],
      coverage.covered_concerns.map { |concern| concern[:description] }
    )
  end

  test "recognizes a covered presence validation" do
    coverage = coverage_for(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        test "title is required" do
          assert true
        end
      end
    RUBY

    assert_equal 1, coverage.covered_count
    assert_equal 1, coverage.missing_count

    assert_equal(
      ["validates presence of title"],
      coverage.covered_concerns.map { |concern| concern[:description] }
    )
  end

  test "recognizes method-style tests" do
    coverage = coverage_for(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        def test_belongs_to_user
          assert true
        end

        def test_title_requires_presence
          assert true
        end
      end
    RUBY

    assert_equal 2, coverage.covered_count
    assert_equal 0, coverage.missing_count
  end

  private

  def coverage_for(test_source)
    inspector = RailsProof::ModelInspector.new(Post)
    model_test_plan = RailsProof::ModelTestPlan.new(inspector)
    test_inspector = RailsProof::TestInspector.new(test_source)

    RailsProof::TestCoveragePlan.new(
      model_test_plan,
      test_inspector
    )
  end
end