require "test_helper"
require "rails_proof/controller_inspector"
require "rails_proof/controller_test_plan"

class RailsProof::ControllerTestPlanTest < ActiveSupport::TestCase
  test "builds one concern for each routed controller action" do
    plan = controller_test_plan

    assert_equal 2, plan.count
  end

  test "builds a successful response concern for index" do
    plan = controller_test_plan

    concern = plan.concerns.find do |candidate|
      candidate[:action] == "index"
    end

    assert_equal :controller_response, concern[:type]
    assert_equal "GET", concern[:verb]
    assert_equal "/posts/index", concern[:path]
    assert_equal "posts_index", concern[:route_name]
    assert_equal "index", concern[:action]
    assert_equal(
      "GET /posts/index responds successfully",
      concern[:description]
    )
  end

  test "builds a successful response concern for show" do
    plan = controller_test_plan

    concern = plan.concerns.find do |candidate|
      candidate[:action] == "show"
    end

    assert_equal :controller_response, concern[:type]
    assert_equal "GET", concern[:verb]
    assert_equal "/posts/show", concern[:path]
    assert_equal "posts_show", concern[:route_name]
    assert_equal "show", concern[:action]
    assert_equal(
      "GET /posts/show responds successfully",
      concern[:description]
    )
  end

  test "preserves route order" do
    plan = controller_test_plan

    assert_equal(
      [
        "GET /posts/index responds successfully",
        "GET /posts/show responds successfully"
      ],
      plan.concerns.map { |concern| concern[:description] }
    )
  end

  private

  def controller_test_plan
    inspector = RailsProof::ControllerInspector.new(PostsController)

    RailsProof::ControllerTestPlan.new(inspector)
  end
end