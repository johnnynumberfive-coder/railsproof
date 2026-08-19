module RailsProof
  class ControllerTestCoveragePlan
    attr_reader :controller_test_plan, :test_inspector

    def initialize(controller_test_plan, test_inspector)
      @controller_test_plan = controller_test_plan
      @test_inspector = test_inspector
    end

    def covered_concerns
      @covered_concerns ||= controller_test_plan.concerns.select do |concern|
        covered?(concern)
      end
    end

    def missing_concerns
      @missing_concerns ||= controller_test_plan.concerns.reject do |concern|
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
      return false unless concern[:type] == :controller_response

      action = normalize(concern[:action])

      test_name.include?(action) &&
        response_language?(test_name)
    end

    def response_language?(test_name)
      [
        "get",
        "post",
        "patch",
        "put",
        "delete",
        "response",
        "respond",
        "success",
        "successful"
      ].any? do |word|
        test_name.split.include?(word)
      end
    end

    def normalize(value)
      value
        .to_s
        .downcase
        .tr("_", " ")
        .gsub(/[^a-z0-9\s]/, " ")
        .split
        .join(" ")
    end
  end
end