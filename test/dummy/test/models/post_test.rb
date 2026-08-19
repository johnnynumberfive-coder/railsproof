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

  test "title_matches? returns false for blank queries" do
    post = Post.new(title: "Example title")

    [nil, "", "   "].each do |query|
      assert_not post.title_matches?(query), "expected #{query.inspect} not to match"
    end
  end

  test "title_matches? performs a case insensitive substring match" do
    post = Post.new(title: "Learning Rails")

    assert post.title_matches?("RAILS")
  end

  test "title_matches? returns false when query is absent from title" do
    post = Post.new(title: "Learning Rails")

    assert_not post.title_matches?("Python")
  end

  test "title_matches? handles a nil title" do
    post = Post.new(title: nil)

    assert_not post.title_matches?("Rails")
  end

  test "title_matches? converts non-string queries to strings" do
    post = Post.new(title: "Release 123")

    assert post.title_matches?(123)
  end

  test "title_matches_exactly? returns false for blank queries" do
    post = Post.new(title: "Learning Rails")

    [nil, "", "   "].each do |query|
      assert_not post.title_matches_exactly?(query), "expected #{query.inspect} not to match exactly"
    end
  end

  test "title_matches_exactly? requires case insensitive whole title equality" do
    post = Post.new(title: "Learning Rails")

    assert post.title_matches_exactly?("LEARNING RAILS")
    assert_not post.title_matches_exactly?("Rails")
  end

  test "title_matches_exactly? converts non string queries to strings" do
    post = Post.new(title: "123")

    assert post.title_matches_exactly?(123)
  end

  test "title_matches_exactly? handles a nil title" do
    post = Post.new(title: nil)

    assert_not post.title_matches_exactly?("Rails")
  end
end