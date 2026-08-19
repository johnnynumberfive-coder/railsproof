require "test_helper"
require "rails_proof/controller_test_writer"

class RailsProof::ControllerTestWriterTest < ActiveSupport::TestCase
  test "renders a GET integration test" do
    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "PostsController",
      concerns: [
        {
          type: :controller_response,
          verb: "GET",
          path: "/posts/index",
          route_name: "posts_index",
          action: "index",
          description: "GET /posts/index responds successfully"
        }
      ]
    )

    assert_includes writer.render, 'test "should get index" do'
    assert_includes writer.render, "get posts_index_url"
    assert_includes writer.render, "assert_response :success"
  end

  test "renders multiple controller tests" do
    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "PostsController",
      concerns: [
        {
          type: :controller_response,
          verb: "GET",
          path: "/posts/index",
          route_name: "posts_index",
          action: "index",
          description: "GET /posts/index responds successfully"
        },
        {
          type: :controller_response,
          verb: "GET",
          path: "/posts/show",
          route_name: "posts_show",
          action: "show",
          description: "GET /posts/show responds successfully"
        }
      ]
    )

    source = writer.render

    assert_includes source, 'test "should get index" do'
    assert_includes source, "get posts_index_url"
    assert_includes source, 'test "should get show" do'
    assert_includes source, "get posts_show_url"
  end

  test "renders a complete integration test file" do
    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "PostsController",
      concerns: [
        {
          type: :controller_response,
          verb: "GET",
          path: "/posts/index",
          route_name: "posts_index",
          action: "index",
          description: "GET /posts/index responds successfully"
        }
      ]
    )

    source = writer.render_test_file

    assert_includes source, 'require "test_helper"'
    assert_includes source,
      "class PostsControllerTest < ActionDispatch::IntegrationTest"
    assert_includes source, 'test "should get index" do'
    assert source.end_with?("end\n")
  end

  test "renders the HTTP verb used by the concern" do
    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "PostsController",
      concerns: [
        {
          type: :controller_response,
          verb: "POST",
          path: "/posts",
          route_name: "posts",
          action: "create",
          description: "POST /posts responds successfully"
        }
      ]
    )

    assert_includes writer.render, 'test "should post create" do'
    assert_includes writer.render, "post posts_url"
  end

  test "rejects a route without a name" do
    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "PostsController",
      concerns: [
        {
          type: :controller_response,
          verb: "GET",
          path: "/posts",
          route_name: nil,
          action: "index",
          description: "GET /posts responds successfully"
        }
      ]
    )

    assert_raises ArgumentError do
      writer.render
    end
  end

  test "rejects unsupported controller concerns" do
    writer = RailsProof::ControllerTestWriter.new(
      controller_class_name: "PostsController",
      concerns: [
        {
          type: :mystery
        }
      ]
    )

    assert_raises ArgumentError do
      writer.render
    end
  end
end