require "test_helper"
require "rails_proof/ai_test_writer"

class RailsProof::AiTestWriterTest < ActiveSupport::TestCase
  test "renders AI generated model test code" do
    writer = RailsProof::AiTestWriter.new(
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: [
        {
          name: "title_matches finds substrings case insensitively",
          test_code: <<~RUBY
            test "title_matches finds substrings case insensitively" do
              post = Post.new(title: "Hello World")

              assert post.title_matches?("hello")
            end
          RUBY
        }
      ]
    )

    source = writer.render

    assert_includes(
      source,
      'test "title_matches finds substrings case insensitively" do'
    )
    assert_includes source, 'post = Post.new(title: "Hello World")'
    assert_includes source, 'assert post.title_matches?("hello")'
  end

  test "renders multiple AI generated tests" do
    writer = RailsProof::AiTestWriter.new(
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: [
        {
          name: "blank query",
          test_code: <<~RUBY
            test "title_matches returns false for blank queries" do
              post = Post.new(title: "Hello")

              assert_not post.title_matches?("")
            end
          RUBY
        },
        {
          name: "nil title",
          test_code: <<~RUBY
            test "title_matches handles a nil title" do
              post = Post.new(title: nil)

              assert_not post.title_matches?("hello")
            end
          RUBY
        }
      ]
    )

    source = writer.render

    assert_includes source, "returns false for blank queries"
    assert_includes source, "handles a nil title"
  end

  test "renders a complete model test file" do
    writer = RailsProof::AiTestWriter.new(
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: [
        {
          name: "blank query",
          test_code: <<~RUBY
            test "title_matches returns false for blank queries" do
              post = Post.new(title: "Hello")

              assert_not post.title_matches?("")
            end
          RUBY
        }
      ]
    )

    source = writer.render_test_file

    assert_includes source, 'require "test_helper"'
    assert_includes source, "class PostTest < ActiveSupport::TestCase"
    assert_includes source, "returns false for blank queries"
    assert source.end_with?("end\n")
  end

  test "renders a complete controller test file" do
    writer = RailsProof::AiTestWriter.new(
      test_class_name: "PostsControllerTest",
      superclass: "ActionDispatch::IntegrationTest",
      concerns: [
        {
          name: "index renders successfully",
          test_code: <<~RUBY
            test "index renders successfully" do
              get posts_index_url

              assert_response :success
            end
          RUBY
        }
      ]
    )

    source = writer.render_test_file

    assert_includes(
      source,
      "class PostsControllerTest < ActionDispatch::IntegrationTest"
    )
    assert_includes source, "get posts_index_url"
  end

  test "rejects a concern without test code" do
    writer = RailsProof::AiTestWriter.new(
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: [
        {
          name: "something useful"
        }
      ]
    )

    assert_raises RailsProof::AiTestWriter::InvalidConcern do
      writer.render
    end
  end

  test "rejects blank test code" do
    writer = RailsProof::AiTestWriter.new(
      test_class_name: "PostTest",
      superclass: "ActiveSupport::TestCase",
      concerns: [
        {
          name: "something useful",
          test_code: "   "
        }
      ]
    )

    assert_raises RailsProof::AiTestWriter::InvalidConcern do
      writer.render
    end
  end
end