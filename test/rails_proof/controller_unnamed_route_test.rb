require "test_helper"
require "rails_proof/controller_test_plan"
require "rails_proof/controller_test_writer"

class RailsProof::ControllerUnnamedRouteTest < ActiveSupport::TestCase
  class FakeInspector
    attr_reader :routes

    def initialize(routes)
      @routes = routes
    end
  end

  test "unnamed routes are not included in the test plan" do
    inspector = FakeInspector.new(
      [
        {
          verb: "POST",
          path: "/admin/users",
          name: nil,
          action: "create"
        }
      ]
    )

    plan = RailsProof::ControllerTestPlan.new(inspector)

    assert_empty plan.concerns
    assert_equal 0, plan.count
  end

  test "named routes remain in the test plan" do
    inspector = FakeInspector.new(
      [
        {
          verb: "GET",
          path: "/admin/users",
          name: "admin_users",
          action: "index"
        }
      ]
    )

    plan = RailsProof::ControllerTestPlan.new(inspector)

    assert_equal 1, plan.count

    concern = plan.concerns.first

    assert_equal :controller_response, concern[:type]
    assert_equal "GET", concern[:verb]
    assert_equal "/admin/users", concern[:path]
    assert_equal "admin_users", concern[:route_name]
    assert_equal "index", concern[:action]
  end

  test "mixed named and unnamed routes keep only generatable concerns" do
    inspector = FakeInspector.new(
      [
        {
          verb: "GET",
          path: "/admin/users",
          name: "admin_users",
          action: "index"
        },
        {
          verb: "POST",
          path: "/admin/users",
          name: nil,
          action: "create"
        },
        {
          verb: "GET",
          path: "/admin/users/new",
          name: "new_admin_user",
          action: "new"
        }
      ]
    )

    plan = RailsProof::ControllerTestPlan.new(inspector)

    assert_equal 2, plan.count

    assert_equal(
      %w[admin_users new_admin_user],
      plan.concerns.map { |concern| concern[:route_name] }
    )
  end

  test "writer can render every concern produced by the plan" do
    inspector = FakeInspector.new(
      [
        {
          verb: "GET",
          path: "/admin/users",
          name: "admin_users",
          action: "index"
        },
        {
          verb: "POST",
          path: "/admin/users",
          name: nil,
          action: "create"
        }
      ]
    )

    plan = RailsProof::ControllerTestPlan.new(inspector)

    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "Admin::UsersController",
      concerns: plan.concerns
    )

    source = writer.render

    assert_includes source, 'test "should get index" do'
    assert_includes source, "get admin_users_url"
    assert_not_includes source, 'test "should post create" do'
  end
end