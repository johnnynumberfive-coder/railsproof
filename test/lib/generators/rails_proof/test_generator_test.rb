require "test_helper"
require "generators/rails_proof/test/test_generator"

class RailsProof::TestGeneratorTest < Rails::Generators::TestCase
  tests RailsProof::TestGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination
  setup :create_user_model

  test "inspects a Rails model with a missing test" do
    output = run_generator ["app/models/user.rb"]

    assert_includes output, "RailsProof inspection"
    assert_includes output, "Model file: app/models/user.rb"
    assert_includes output, "Model class: User"
    assert_includes output, "Test file: test/models/user_test.rb"
    assert_includes output, "Test status: missing"
    refute_includes output, "Test cases:"
    assert_includes output, "Source associations: 0"
    assert_includes output, "Source validations: 0"
  end

  test "reports an existing empty model test" do
    create_empty_user_test

    output = run_generator ["app/models/user.rb"]

    assert_includes output, "Test status: exists"
    assert_includes output, "Test cases: 0"
  end

  test "counts both Minitest declaration styles" do
    create_user_test_with_test_cases

    output = run_generator ["app/models/user.rb"]

    assert_includes output, "Test status: exists"
    assert_includes output, "Test cases: 2"
  end

  test "reports source associations and validations" do
    create_post_model

    output = run_generator ["app/models/post.rb"]

    assert_includes output, "Model class: Post"
    assert_includes output, "Source associations: 1"
    assert_includes output, "belongs_to :user"
    assert_includes output, "Source validations: 1"
    assert_includes output, "validates :title, presence: true"
  end

  test "reports runtime model information" do
    create_post_model

    output = run_generator ["app/models/post.rb"]

    assert_includes output, "Runtime inspection: available"
    assert_includes output, "Table: posts"
    assert_includes output, "title string null=true"
    assert_includes output, "user_id integer null=false"
    assert_includes output, "Runtime associations: 1"
    assert_includes output, "belongs_to :user class=User foreign_key=user_id"
    assert_includes output, "Runtime validators: 2"
    assert_includes output, "attributes=[:title]"
    assert_includes output, "attributes=[:user]"
  end

  test "reports the suggested model tests" do
    create_post_model

    output = run_generator ["app/models/post.rb"]

    assert_includes output, "Suggested tests: 2"
    assert_includes output, "belongs_to :user"
    assert_includes output, "validates presence of title"
  end

  test "does not duplicate the implicit belongs_to presence validation" do
    create_post_model

    output = run_generator ["app/models/post.rb"]

    refute_includes output, "validates presence of user"
  end

  test "creates a missing model test with suggested tests" do
    create_post_model

    run_generator ["app/models/post.rb"]

    assert_file "test/models/post_test.rb" do |source|
      assert_includes source, 'require "test_helper"'
      assert_includes source, "class PostTest < ActiveSupport::TestCase"
      assert_includes source, 'test "belongs to user" do'
      assert_includes source, 'test "validates presence of title" do'
    end
  end

  test "adds missing tests to an existing empty model test" do
    create_post_model
    create_empty_post_test

    run_generator ["app/models/post.rb"]

    assert_file "test/models/post_test.rb" do |source|
      assert_includes source, 'test "belongs to user" do'
      assert_includes source, 'test "validates presence of title" do'
    end
  end

  test "adds only the missing test to a partially covered model test" do
    create_post_model
    create_partially_covered_post_test

    run_generator ["app/models/post.rb"]

    source = File.read(
      File.join(destination_root, "test/models/post_test.rb")
    )

    assert_equal 1, source.scan('test "belongs to user" do').count
    assert_equal 1, source.scan('test "validates presence of title" do').count
  end

  test "does not modify a fully covered model test" do
    create_post_model
    create_covered_post_test

    path = File.join(destination_root, "test/models/post_test.rb")
    before = File.read(path)

    run_generator ["app/models/post.rb"]

    assert_equal before, File.read(path)
  end

  private

  def create_user_model
    mkdir_p File.join(destination_root, "app/models")

    File.write(
      File.join(destination_root, "app/models/user.rb"),
      <<~RUBY
        class User < ApplicationRecord
        end
      RUBY
    )
  end

  def create_post_model
    mkdir_p File.join(destination_root, "app/models")

    File.write(
      File.join(destination_root, "app/models/post.rb"),
      <<~RUBY
        class Post < ApplicationRecord
          belongs_to :user

          validates :title, presence: true
        end
      RUBY
    )
  end

  def create_empty_user_test
    mkdir_p File.join(destination_root, "test/models")

    File.write(
      File.join(destination_root, "test/models/user_test.rb"),
      <<~RUBY
        require "test_helper"

        class UserTest < ActiveSupport::TestCase
        end
      RUBY
    )
  end

  def create_user_test_with_test_cases
    mkdir_p File.join(destination_root, "test/models")

    File.write(
      File.join(destination_root, "test/models/user_test.rb"),
      <<~RUBY
        require "test_helper"

        class UserTest < ActiveSupport::TestCase
          test "name can be assigned" do
            assert_equal "John", User.new(name: "John").name
          end

          def test_email_can_be_assigned
            assert_equal "john@example.com", User.new(email: "john@example.com").email
          end
        end
      RUBY
    )
  end

  def create_empty_post_test
    mkdir_p File.join(destination_root, "test/models")

    File.write(
      File.join(destination_root, "test/models/post_test.rb"),
      <<~RUBY
        require "test_helper"

        class PostTest < ActiveSupport::TestCase
        end
      RUBY
    )
  end

  def create_covered_post_test
    mkdir_p File.join(destination_root, "test/models")

    File.write(
      File.join(destination_root, "test/models/post_test.rb"),
      <<~RUBY
        require "test_helper"

        class PostTest < ActiveSupport::TestCase
          test "belongs to user" do
            assert true
          end

          test "validates presence of title" do
            assert true
          end
        end
      RUBY
    )
  end

  def create_partially_covered_post_test
    mkdir_p File.join(destination_root, "test/models")

    File.write(
      File.join(destination_root, "test/models/post_test.rb"),
      <<~RUBY
        require "test_helper"

        class PostTest < ActiveSupport::TestCase
          test "belongs to user" do
            assert true
          end
        end
      RUBY
    )
  end
end