require "test_helper"
require "rails_proof/test_inspector"

class RailsProof::TestInspectorTest < ActiveSupport::TestCase
  test "reports an empty test file" do
    inspector = RailsProof::TestInspector.new(<<~RUBY)
      require "test_helper"

      class PostTest < ActiveSupport::TestCase
      end
    RUBY

    assert inspector.empty?
    assert_equal 0, inspector.count
    assert_empty inspector.test_cases
  end

  test "finds Rails-style test declarations" do
    inspector = RailsProof::TestInspector.new(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        test "belongs to user" do
          assert true
        end

        test "requires a title" do
          assert true
        end
      end
    RUBY

    assert_equal 2, inspector.count
    assert_equal(
      [
        {
          style: :rails,
          name: "belongs to user"
        },
        {
          style: :rails,
          name: "requires a title"
        }
      ],
      inspector.test_cases
    )
  end

  test "finds method-style test declarations" do
    inspector = RailsProof::TestInspector.new(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        def test_belongs_to_user
          assert true
        end

        def test_requires_a_title
          assert true
        end
      end
    RUBY

    assert_equal 2, inspector.count
    assert_equal(
      [
        {
          style: :method,
          name: "belongs to user",
          method_name: "test_belongs_to_user"
        },
        {
          style: :method,
          name: "requires a title",
          method_name: "test_requires_a_title"
        }
      ],
      inspector.test_cases
    )
  end

  test "finds both Minitest declaration styles" do
    inspector = RailsProof::TestInspector.new(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        test "belongs to user" do
          assert true
        end

        def test_requires_a_title
          assert true
        end
      end
    RUBY

    assert_equal 2, inspector.count
    assert_equal(
      [
        "belongs to user",
        "requires a title"
      ],
      inspector.test_cases.map { |test_case| test_case[:name] }
    )
  end

  test "ignores commented test declarations" do
    inspector = RailsProof::TestInspector.new(<<~RUBY)
      class PostTest < ActiveSupport::TestCase
        # test "the truth" do
        #   assert true
        # end

        # def test_something
        #   assert true
        # end
      end
    RUBY

    assert inspector.empty?
  end
end