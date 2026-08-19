require "test_helper"
require "rails_proof/controller_inspector"

class RailsProof::ControllerInspectorTest < ActiveSupport::TestCase
  test "reports the controller name and path" do
    inspector = RailsProof::ControllerInspector.new(PostsController)

    assert_equal "PostsController", inspector.controller_name
    assert_equal "posts", inspector.controller_path
  end

  test "reports dispatchable controller actions" do
    inspector = RailsProof::ControllerInspector.new(PostsController)

    assert_equal(
      ["index", "show"],
      inspector.actions
    )
  end

  test "reports routes for the controller" do
    inspector = RailsProof::ControllerInspector.new(PostsController)

    assert_equal(
      [
        {
          name: "posts_index",
          verb: "GET",
          path: "/posts/index",
          action: "index"
        },
        {
          name: "posts_show",
          verb: "GET",
          path: "/posts/show",
          action: "show"
        }
      ],
      inspector.routes
    )
  end

  test "does not include routes for other controllers" do
    inspector = RailsProof::ControllerInspector.new(PostsController)

    controller_paths = inspector.routes.map do |route|
      route[:path]
    end

    refute_includes controller_paths, "/up"
  end
end