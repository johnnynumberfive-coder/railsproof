require "test_helper"

class PostTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "belongs to user" do
    association = Post.reflect_on_association(:user)

    assert_not_nil association
    assert_equal :belongs_to, association.macro
  end

  test "validates presence of title" do
    record = Post.new(title: nil)

    record.validate

    assert record.errors.of_kind?(:title, :blank)
  end
end
