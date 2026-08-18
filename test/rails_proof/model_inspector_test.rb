require "test_helper"
require "rails_proof/model_inspector"

class RailsProof::ModelInspectorTest < ActiveSupport::TestCase
  test "reports model and table names" do
    inspector = RailsProof::ModelInspector.new(Post)

    assert_equal "Post", inspector.model_name
    assert_equal "posts", inspector.table_name
  end

  test "reports database columns" do
    inspector = RailsProof::ModelInspector.new(Post)

    title = inspector.columns.find { |column| column[:name] == "title" }
    user_id = inspector.columns.find { |column| column[:name] == "user_id" }

    assert_equal :string, title[:type]
    assert_equal true, title[:null]
    assert_nil title[:default]

    assert_equal :integer, user_id[:type]
    assert_equal false, user_id[:null]
    assert_nil user_id[:default]
  end

  test "reports associations" do
    inspector = RailsProof::ModelInspector.new(Post)

    association = inspector.associations.find do |candidate|
      candidate[:name] == :user
    end

    assert_equal :belongs_to, association[:macro]
    assert_equal "User", association[:class_name]
    assert_equal "user_id", association[:foreign_key]
    assert_equal({}, association[:options])
  end

  test "reports explicit and implicit validators" do
    inspector = RailsProof::ModelInspector.new(Post)

    presence_validators = inspector.validators.select do |validator|
      validator[:class_name].end_with?("PresenceValidator")
    end

    validated_attributes = presence_validators.flat_map do |validator|
      validator[:attributes]
    end

    assert_includes validated_attributes, :title
    assert_includes validated_attributes, :user
  end
end