require "rails_proof/test_inspector"
require "rails_proof/ai_test_validator"
require "rails_proof/ai_test_identity"

module RailsProof
  class AiConcernFilter
    SkippedConcern = Struct.new(
      :concern,
      :reason,
      keyword_init: true
    )

    attr_reader :input_concerns,
      :existing_tests,
      :review_findings

    def initialize(
      concerns:,
      existing_tests:,
      review_findings: []
    )
      @input_concerns = concerns
      @existing_tests = existing_tests.to_s
      @review_findings = review_findings
    end

    def concerns
      filter_result[:concerns]
    end

    def skipped
      filter_result[:skipped]
    end

    private

    def filter_result
      @filter_result ||= build_filter_result
    end

    def build_filter_result
      accepted = []
      skipped = []

      input_concerns.each do |concern|
        reason = duplicate_reason(
          concern: concern,
          accepted: accepted
        )

        if reason
          skipped << SkippedConcern.new(
            concern: concern,
            reason: reason
          )

          next
        end

        accepted << concern
      end

      {
        concerns: accepted,
        skipped: skipped
      }
    end

    def duplicate_reason(concern:, accepted:)
      return :existing_test if matches_existing_test?(concern)
      return :needs_review if matches_review_finding?(concern)

      if structurally_valid?(concern) &&
          matches_accepted_concern?(concern, accepted)
        return :duplicate_suggestion
      end

      nil
    end

    def matches_existing_test?(concern)
      concern_keys = RailsProof::AiTestIdentity.name_keys(
        name: concern_name(concern),
        test_code: concern_test_code(concern)
      )

      (concern_keys & existing_test_keys).any?
    end

    def matches_review_finding?(concern)
      review_findings.any? do |finding|
        RailsProof::AiTestIdentity.same?(
          first_name: concern_name(concern),
          first_test_code: concern_test_code(concern),
          second_name: finding["name"] || finding[:name],
          second_test_code:
            finding["test_code"] || finding[:test_code]
        )
      end
    end

    def matches_accepted_concern?(concern, accepted)
      accepted.any? do |existing|
        next false unless structurally_valid?(existing)

        RailsProof::AiTestIdentity.same_candidate?(
          first_name: concern_name(concern),
          first_test_code: concern_test_code(concern),
          second_name: concern_name(existing),
          second_test_code: concern_test_code(existing)
        )
      end
    end

    def existing_test_keys
      @existing_test_keys ||= RailsProof::TestInspector
        .new(existing_tests)
        .test_cases
        .filter_map do |test_case|
          RailsProof::AiTestIdentity.normalize_name(
            test_case[:name]
          )
        end
        .uniq
    end

    def concern_name(concern)
      concern[:name] || concern["name"]
    end

    def concern_test_code(concern)
      concern[:test_code] || concern["test_code"]
    end

    def structurally_valid?(concern)
      RailsProof::AiTestValidator
        .new(concern_test_code(concern))
        .validate
        .valid?
    end
  end
end