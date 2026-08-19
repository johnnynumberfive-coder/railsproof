require "digest"
require "set"
require "rails_proof/test_inspector"

module RailsProof
  class AiTestIdentity
    class << self
      def name_keys(name:, test_code:)
        names = [name]

        if test_code.is_a?(String)
          inspector = RailsProof::TestInspector.new(test_code)

          names.concat(
            inspector.test_cases.map do |test_case|
              test_case[:name]
            end
          )
        end

        names
          .filter_map { |value| normalize_name(value) }
          .uniq
      end

      def test_fingerprint(test_code)
        canonical = canonical_test_code(test_code)

        return nil unless canonical

        Digest::SHA256.hexdigest(canonical)
      end

      def assertion_keys(test_code)
        return [] unless test_code.is_a?(String)
        return [] if test_code.strip.empty?

        test_code.each_line.filter_map do |line|
          assertion = normalize_assertion(line)

          next unless assertion
          next if trivial_assertion?(assertion)

          assertion
        end.uniq
      end

      def behavior_keys(test_code)
        return [] unless test_code.is_a?(String)
        return [] if test_code.strip.empty?

        context = []
        keys = []

        test_code.each_line do |line|
          normalized = normalize_code_line(line)

          next if normalized.empty?
          next if normalized.start_with?("#")
          next if test_declaration?(normalized)
          next if normalized == "end"

          assertion = normalize_assertion(normalized)

          if assertion
            unless trivial_assertion?(assertion)
              keys << behavior_key(
                context: context,
                assertion: assertion
              )
            end

            next
          end

          context << normalized
        end

        keys.uniq
      end

      def same?(
        first_name:,
        first_test_code:,
        second_name:,
        second_test_code:
      )
        return true if same_name?(
          first_name: first_name,
          first_test_code: first_test_code,
          second_name: second_name,
          second_test_code: second_test_code
        )

        same_meaningful_behavior?(
          first_test_code: first_test_code,
          second_test_code: second_test_code
        )
      end

      def same_candidate?(
        first_name:,
        first_test_code:,
        second_name:,
        second_test_code:
      )
        return true if same?(
          first_name: first_name,
          first_test_code: first_test_code,
          second_name: second_name,
          second_test_code: second_test_code
        )

        same_test_body?(
          first_test_code,
          second_test_code
        )
      end

      def normalize_name(value)
        normalized = value
          .to_s
          .downcase
          .gsub(/[^a-z0-9]+/, " ")
          .strip
          .squeeze(" ")

        normalized.empty? ? nil : normalized
      end

      private

      def same_name?(
        first_name:,
        first_test_code:,
        second_name:,
        second_test_code:
      )
        first_names = name_keys(
          name: first_name,
          test_code: first_test_code
        )

        second_names = name_keys(
          name: second_name,
          test_code: second_test_code
        )

        (first_names & second_names).any?
      end

      def same_meaningful_behavior?(
        first_test_code:,
        second_test_code:
      )
        first_behaviors = behavior_keys(first_test_code)
        second_behaviors = behavior_keys(second_test_code)

        return false if first_behaviors.empty?
        return false if second_behaviors.empty?

        first_set = first_behaviors.to_set
        second_set = second_behaviors.to_set

        first_set.subset?(second_set) ||
          second_set.subset?(first_set)
      end

      def same_test_body?(first_test_code, second_test_code)
        first_fingerprint = test_fingerprint(first_test_code)
        second_fingerprint = test_fingerprint(second_test_code)

        return false unless first_fingerprint
        return false unless second_fingerprint

        first_fingerprint == second_fingerprint
      end

      def canonical_test_code(test_code)
        return nil unless test_code.is_a?(String)
        return nil if test_code.strip.empty?

        source = test_code.dup

        source.sub!(
          /^\s*test\s*(?:\(\s*)?(["']).+?\1\s*\)?\s+do\b/,
          "test do"
        )

        source
          .each_line
          .map(&:strip)
          .reject(&:empty?)
          .join(" ")
          .gsub(/\s+/, " ")
          .strip
      end

      def normalize_code_line(line)
        line
          .strip
          .gsub(/\s+/, " ")
      end

      def test_declaration?(line)
        line.match?(
          /\Atest\s*(?:\(\s*)?(["']).+?\1\s*\)?\s+do\b/
        ) ||
          line.match?(/\Adef\s+test_[a-zA-Z0-9_!?]+/)
      end

      def normalize_assertion(line)
        normalized = line
          .strip
          .gsub(/\s+/, " ")

        return nil unless assertion_line?(normalized)

        normalized = normalized.sub(
          /\Arefute_/,
          "assert_not_"
        )

        normalized = normalized.sub(
          /\Arefute\b/,
          "assert_not"
        )

        normalized
      end

      def assertion_line?(line)
        line.match?(
          /\A(?:assert|assert_not|refute)(?:_[a-zA-Z0-9_!?]+)?(?:\s|\()/
        )
      end

      def trivial_assertion?(assertion)
        normalized = assertion
          .delete("()")
          .strip
          .gsub(/\s+/, " ")

        [
          "assert true",
          "assert false",
          "assert_not true",
          "assert_not false"
        ].include?(normalized)
      end

      def behavior_key(context:, assertion:)
        normalized_context = context
          .map { |line| normalize_code_line(line) }
          .join(" | ")

        "#{normalized_context} => #{assertion}"
      end
    end
  end
end