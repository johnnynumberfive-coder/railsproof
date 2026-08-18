require "test_helper"
require "rails_proof/model_inspector"
require "rails_proof/model_test_plan"

class RailsProof::ModelTestPlanTest < ActiveSupport::TestCase
  test "builds an association concern" do
    plan = test_plan_for(Post)

    concern = plan.concerns.find do |candidate|
      candidate[:type] == :association
    end

    assert_equal :belongs_to, concern[:macro]
    assert_equal :user, concern[:name]
    assert_equal "belongs_to :user", concern[:description]
  end

  test "builds an explicit presence validation concern" do
    plan = test_plan_for(Post)

    concern = plan.concerns.find do |candidate|
      candidate[:type] == :validation &&
        candidate[:attribute] == :title
    end

    assert_equal :presence, concern[:validation]
    assert_equal "validates presence of title", concern[:description]
  end

  test "does not duplicate the implicit belongs_to presence validation" do
    plan = test_plan_for(Post)

    user_presence_concerns = plan.concerns.select do |concern|
      concern[:type] == :validation &&
        concern[:attribute] == :user
    end

    assert_empty user_presence_concerns
  end

  test "produces two test concerns for Post" do
    plan = test_plan_for(Post)

    assert_equal 2, plan.count
    assert_equal(
      [
        "belongs_to :user",
        "validates presence of title"
      ],
      plan.concerns.map { |concern| concern[:description] }
    )
  end

  private

  def test_plan_for(model_class)
    inspector = RailsProof::ModelInspector.new(model_class)

    RailsProof::ModelTestPlan.new(inspector)
  end
end