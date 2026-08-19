require "test_helper"
require "rails_proof/ai_test_validator"

class RailsProof::AiTestValidatorTest < ActiveSupport::TestCase
  test "accepts a valid single Minitest block" do
    validator = RailsProof::AiTestValidator.new(
      <<~RUBY
        test "title_matches finds a substring" do
          post = Post.new(title: "Learning Ruby")

          assert post.title_matches?("Ruby")
        end
      RUBY
    )

    result = validator.validate

    assert result.valid?
    assert_empty result.errors
  end

  test "rejects invalid Ruby" do
    validator = RailsProof::AiTestValidator.new(
      <<~RUBY
        test "broken" do
          assert true
      RUBY
    )

    result = validator.validate

    refute result.valid?
    assert_includes result.errors, "test code is not valid Ruby"
  end

  test "rejects multiple test declarations" do
    validator = RailsProof::AiTestValidator.new(
      <<~RUBY
        test "one" do
          assert true
        end

        test "two" do
          assert true
        end
      RUBY
    )

    result = validator.validate

    refute result.valid?
    assert_includes(
      result.errors,
      "test code must contain exactly one test declaration"
    )
  end

  test "rejects code without a test declaration" do
    validator = RailsProof::AiTestValidator.new(
      <<~RUBY
        post = Post.new(title: "Hello")
        assert post.title_matches?("Hello")
      RUBY
    )

    result = validator.validate

    refute result.valid?
    assert_includes(
      result.errors,
      "test code must contain exactly one test declaration"
    )
  end

  test "rejects a class declaration" do
    validator = RailsProof::AiTestValidator.new(
      <<~RUBY
        class PostTest < ActiveSupport::TestCase
          test "something" do
            assert true
          end
        end
      RUBY
    )

    result = validator.validate

    refute result.valid?
    assert_includes(
      result.errors,
      "test code must not contain a class declaration"
    )
  end

  test "rejects a require statement" do
    validator = RailsProof::AiTestValidator.new(
      <<~RUBY
        require "test_helper"

        test "something" do
          assert true
        end
      RUBY
    )

    result = validator.validate

    refute result.valid?
    assert_includes(
      result.errors,
      "test code must not contain a require statement"
    )
  end

  test "rejects Markdown code fences" do
    validator = RailsProof::AiTestValidator.new(
      <<~TEXT
        ```ruby
        test "something" do
          assert true
        end
        ```
      TEXT
    )

    result = validator.validate

    refute result.valid?
    assert_includes(
      result.errors,
      "test code must not contain Markdown code fences"
    )
  end

  test "rejects blank test code" do
    validator = RailsProof::AiTestValidator.new("   ")

    result = validator.validate

    refute result.valid?
    assert_includes(
      result.errors,
      "test code must be a nonblank string"
    )
  end
end