module RailsProof
  class TestCoveragePlan
    attr_reader :model_test_plan, :test_inspector

    def initialize(model_test_plan, test_inspector)
      @model_test_plan = model_test_plan
      @test_inspector = test_inspector
    end

    def covered_concerns
      @covered_concerns ||= model_test_plan.concerns.select do |concern|
        covered?(concern)
      end
    end

    def missing_concerns
      @missing_concerns ||= model_test_plan.concerns.reject do |concern|
        covered?(concern)
      end
    end

    def covered_count
      covered_concerns.count
    end

    def missing_count
      missing_concerns.count
    end

    private

    def covered?(concern)
      test_names.any? do |test_name|
        matches_concern?(test_name, concern)
      end
    end

    def test_names
      @test_names ||= test_inspector.test_cases.map do |test_case|
        normalize(test_case[:name])
      end
    end

    def matches_concern?(test_name, concern)
      case concern[:type]
      when :association
        association_covered?(test_name, concern)
      when :validation
        validation_covered?(test_name, concern)
      else
        false
      end
    end

    def association_covered?(test_name, concern)
      macro = normalize(concern[:macro].to_s)
      name = normalize(concern[:name].to_s)

      test_name.include?(macro) &&
        test_name.include?(name)
    end

    def validation_covered?(test_name, concern)
      attribute = normalize(concern[:attribute].to_s)

      test_name.include?(attribute) &&
        (
          test_name.include?("presence") ||
          test_name.include?("present") ||
          test_name.include?("required") ||
          test_name.include?("requires")
        )
    end

    def normalize(value)
      value
        .downcase
        .tr("_", " ")
        .gsub(/[^a-z0-9\s]/, " ")
        .split
        .join(" ")
    end
  end
end