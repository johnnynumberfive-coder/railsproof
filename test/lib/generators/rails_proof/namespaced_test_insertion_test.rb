require "test_helper"
require "generators/rails_proof/test/test_generator"

class RailsProof::NamespacedTestInsertionTest < Rails::Generators::TestCase
  tests RailsProof::TestGenerator
  destination Rails.root.join("tmp/namespaced_generators")
  setup :prepare_destination

  setup do
    create_post_model
    create_namespaced_post_test
  end

  test "adds deterministic tests inside a namespaced test class" do
    run_generator ["app/models/post.rb"]

    source = File.read(
      File.join(
        destination_root,
        "test/models/post_test.rb"
      )
    )

    class_match = source.match(
      /
        \A.*?
        ^\s{2}class\ PostTest\ <\ ActiveSupport::TestCase\n
        (?<body>.*?)
        ^\s{2}end\s*$
      /mx
    )

    assert_not_nil class_match

    assert_includes(
      class_match[:body],
      'test "belongs to user" do'
    )

    assert_includes(
      class_match[:body],
      'test "validates presence of title" do'
    )
  end

  private

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

  def create_namespaced_post_test
    mkdir_p File.join(destination_root, "test/models")

    File.write(
      File.join(destination_root, "test/models/post_test.rb"),
      <<~RUBY
        require "test_helper"

        module Example
          class PostTest < ActiveSupport::TestCase
          end
        end
      RUBY
    )
  end
end