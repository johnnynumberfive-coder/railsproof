module RailsProof
  class AiTestPlanner
    class InvalidResponse < StandardError; end

    attr_reader :target_type,
      :class_name,
      :source,
      :existing_tests,
      :deterministic_concerns,
      :client

    def initialize(
      target_type:,
      class_name:,
      source:,
      existing_tests:,
      deterministic_concerns:,
      client:
    )
      @target_type = target_type
      @class_name = class_name
      @source = source
      @existing_tests = existing_tests
      @deterministic_concerns = deterministic_concerns
      @client = client
    end

    def concerns
      @concerns ||= suggestions.map do |suggestion|
        normalize_suggestion(suggestion)
      end
    end

    def context
      {
        target_type: target_type,
        class_name: class_name,
        source: source,
        existing_tests: existing_tests,
        deterministic_concerns: deterministic_concerns
      }
    end

    private

    def suggestions
      response = client.suggest_tests(context: context)

      unless response.is_a?(Array)
        raise InvalidResponse,
          "AI client must return an array of test suggestions"
      end

      response
    end

    def normalize_suggestion(suggestion)
      unless suggestion.respond_to?(:[])
        raise InvalidResponse,
          "AI test suggestion must be a hash-like object"
      end

      name = suggestion[:name] || suggestion["name"]
      reason = suggestion[:reason] || suggestion["reason"]
      test_code = suggestion[:test_code] || suggestion["test_code"]

      unless name.is_a?(String) && name.strip.present?
        raise InvalidResponse,
          "AI test suggestion must include a name"
      end

      unless reason.is_a?(String) && reason.strip.present?
        raise InvalidResponse,
          "AI test suggestion must include a reason"
      end

      if !test_code.nil? &&
          (!test_code.is_a?(String) || test_code.strip.blank?)
        raise InvalidResponse,
          "AI test suggestion test_code must be a nonblank string"
      end

      concern = {
        type: :ai,
        name: name.strip,
        reason: reason.strip,
        description: name.strip
      }

      concern[:test_code] = test_code.strip if test_code.present?

      concern
    end
  end
end