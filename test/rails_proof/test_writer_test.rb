require "test_helper"
require "rails_proof/test_writer"

class RailsProof::TestWriterTest < ActiveSupport::TestCase
  test "renders an association test" do
    writer = RailsProof::TestWriter.new(
      model_class_name: "Post",
      concerns: [
        {
          type: :association,
          macro: :belongs_to,
          name: :user,
          description: "belongs_to :user"
        }
      ]
    )

    assert_includes writer.render, 'test "belongs to user" do'
    assert_includes writer.render, "Post.reflect_on_association(:user)"
    assert_includes writer.render, "assert_not_nil association"
    assert_includes writer.render, "assert_equal :belongs_to, association.macro"
  end

  test "renders a presence validation test" do
    writer = RailsProof::TestWriter.new(
      model_class_name: "Post",
      concerns: [
        {
          type: :validation,
          validation: :presence,
          attribute: :title,
          description: "validates presence of title"
        }
      ]
    )

    assert_includes writer.render, 'test "validates presence of title" do'
    assert_includes writer.render, "record = Post.new(title: nil)"
    assert_includes writer.render, "record.validate"
    assert_includes writer.render,
      "assert record.errors.of_kind?(:title, :blank)"
  end

  test "renders a complete model test file" do
    writer = RailsProof::TestWriter.new(
      model_class_name: "Post",
      concerns: [
        {
          type: :association,
          macro: :belongs_to,
          name: :user,
          description: "belongs_to :user"
        },
        {
          type: :validation,
          validation: :presence,
          attribute: :title,
          description: "validates presence of title"
        }
      ]
    )

    source = writer.render_test_file

    assert_includes source, 'require "test_helper"'
    assert_includes source, "class PostTest < ActiveSupport::TestCase"
    assert_includes source, 'test "belongs to user" do'
    assert_includes source, 'test "validates presence of title" do'
    assert source.end_with?("end\n")
  end

  test "rejects unsupported concerns" do
    writer = RailsProof::TestWriter.new(
      model_class_name: "Post",
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