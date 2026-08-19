require "test_helper"
require "rails_proof/controller_inspector"
require "rails_proof/controller_test_plan"
require "rails_proof/test_inspector"
require "rails_proof/controller_test_coverage_plan"

class RailsProof::ControllerTestCoveragePlanTest < ActiveSupport::TestCase
  test "recognizes Rails-generated controller tests as covered" do
    coverage = coverage_for(<<~RUBY)
      require "test_helper"

      class PostsControllerTest < ActionDispatch::IntegrationTest
        test "should get index" do
          get posts_index_url
          assert_response :success
        end

        test "should get show" do
          get posts_show_url
          assert_response :success
        end
      end
    RUBY

    assert_equal 2, coverage.covered_count
    assert_equal 0, coverage.missing_count
  end

  test "reports all controller concerns missing for an empty test" do
    coverage = coverage_for(<<~RUBY)
      require "test_helper"

      class PostsControllerTest < ActionDispatch::IntegrationTest
      end
    RUBY

    assert_equal 0, coverage.covered_count
    assert_equal 2, coverage.missing_count

    assert_equal(
      [
        "GET /posts/index responds successfully",
        "GET /posts/show responds successfully"
      ],
      coverage.missing_concerns.map { |concern| concern[:description] }
    )
  end

  test "reports partial controller coverage" do
    coverage = coverage_for(<<~RUBY)
      require "test_helper"

      class PostsControllerTest < ActionDispatch::IntegrationTest
        test "should get index" do
          get posts_index_url
          assert_response :success
        end
      end
    RUBY

    assert_equal 1, coverage.covered_count
    assert_equal 1, coverage.missing_count

    assert_equal(
      ["GET /posts/show responds successfully"],
      coverage.missing_concerns.map { |concern| concern[:description] }
    )
  end

  test "does not count an unrelated action name alone as coverage" do
    coverage = coverage_for(<<~RUBY)
      require "test_helper"

      class PostsControllerTest < ActionDispatch::IntegrationTest
        test "index has a descriptive title" do
          assert true
        end
      end
    RUBY

    assert_equal 0, coverage.covered_count
    assert_equal 2, coverage.missing_count
  end

  test "recognizes method-style controller tests" do
    coverage = coverage_for(<<~RUBY)
      require "test_helper"

      class PostsControllerTest < ActionDispatch::IntegrationTest
        def test_get_index
          get posts_index_url
          assert_response :success
        end

        def test_get_show
          get posts_show_url
          assert_response :success
        end
      end
    RUBY

    assert_equal 2, coverage.covered_count
    assert_equal 0, coverage.missing_count
  end

  private

  def coverage_for(test_source)
    inspector = RailsProof::ControllerInspector.new(PostsController)
    controller_test_plan = RailsProof::ControllerTestPlan.new(inspector)
    test_inspector = RailsProof::TestInspector.new(test_source)

    RailsProof::ControllerTestCoveragePlan.new(
      controller_test_plan,
      test_inspector
    )
  end
end