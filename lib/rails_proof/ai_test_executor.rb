require "pathname"
require "rails_proof/ai_test_validator"
require "rails_proof/ai_test_writer"
require "rails_proof/ai_concern_filter"
require "rails_proof/test_runner"
require "rails_proof/review_store"
require "rails_proof/test_file_inserter"

module RailsProof
  class AiTestExecutor
    Result = Struct.new(
      :concern,
      :status,
      :errors,
      :test_output,
      :review_path,
      :skip_reason,
      keyword_init: true
    ) do
      def kept?
        status == :kept
      end

      def rejected?
        status == :rejected
      end

      def needs_review?
        status == :needs_review
      end

      def skipped?
        status == :skipped
      end
    end

    attr_reader :root,
                :target_path,
                :test_file_path,
                :test_class_name,
                :superclass,
                :concerns,
                :runner_class,
                :review_store

    def initialize(
      root:,
      test_file_path:,
      test_class_name:,
      superclass:,
      concerns:,
      target_path: nil,
      runner_class: RailsProof::TestRunner,
      review_store: nil
    )
      @root = Pathname.new(root)
      @target_path = target_path
      @test_file_path = test_file_path
      @test_class_name = test_class_name
      @superclass = superclass
      @concerns = concerns
      @runner_class = runner_class
      @review_store = review_store ||
        RailsProof::ReviewStore.new(root: @root)
    end

    def execute
      filter = RailsProof::AiConcernFilter.new(
        concerns: concerns,
        existing_tests: existing_test_source,
        review_findings: outstanding_review_findings
      )

      results = filter.concerns.map do |concern|
        execute_concern(concern)
      end

      results.concat(
        filter.skipped.map do |skipped|
          skipped_result(skipped)
        end
      )

      results
    end

    private

    def execute_concern(concern)
      test_code = concern[:test_code] || concern["test_code"]
      validation = RailsProof::AiTestValidator.new(test_code).validate

      unless validation.valid?
        return Result.new(
          concern: concern,
          status: :rejected,
          errors: validation.errors,
          test_output: nil,
          review_path: nil,
          skip_reason: nil
        )
      end

      previous_state = capture_file_state

      write_candidate(concern)

      test_result = runner.run

      if test_result.passed?
        Result.new(
          concern: concern,
          status: :kept,
          errors: [],
          test_output: test_result.output,
          review_path: nil,
          skip_reason: nil
        )
      else
        restore_file_state(previous_state)

        review_path, persistence_error =
          persist_review(
            concern: concern,
            test_output: test_result.output
          )

        errors = [
          "candidate test failed against application"
        ]

        errors << persistence_error if persistence_error

        Result.new(
          concern: concern,
          status: :needs_review,
          errors: errors,
          test_output: test_result.output,
          review_path: review_path,
          skip_reason: nil
        )
      end
    rescue StandardError => error
      restore_file_state(previous_state) if defined?(previous_state)

      Result.new(
        concern: concern,
        status: :rejected,
        errors: [error.message],
        test_output: nil,
        review_path: nil,
        skip_reason: nil
      )
    end

    def skipped_result(skipped)
      Result.new(
        concern: skipped.concern,
        status: :skipped,
        errors: [],
        test_output: nil,
        review_path: nil,
        skip_reason: skipped.reason
      )
    end

    def existing_test_source
      return "" unless absolute_test_file_path.file?

      absolute_test_file_path.read
    end

    def outstanding_review_findings
      return [] unless target_path
      return [] unless review_store.respond_to?(:outstanding_findings)

      review_store.outstanding_findings(
        target_path: target_path,
        test_file_path: test_file_path
      )
    end

    def absolute_test_file_path
      @absolute_test_file_path ||=
        root.join(test_file_path)
    end

    def capture_file_state
      if absolute_test_file_path.file?
        {
          existed: true,
          content: absolute_test_file_path.read
        }
      else
        {
          existed: false,
          content: nil
        }
      end
    end

    def restore_file_state(state)
      return unless state

      if state[:existed]
        absolute_test_file_path.write(
          state[:content]
        )
      elsif absolute_test_file_path.exist?
        absolute_test_file_path.delete
      end
    end

    def write_candidate(concern)
      writer = RailsProof::AiTestWriter.new(
        test_class_name: test_class_name,
        superclass: superclass,
        concerns: [concern]
      )

      if absolute_test_file_path.file?
        insert_into_existing_file(
          writer.render
        )
      else
        absolute_test_file_path.dirname.mkpath

        absolute_test_file_path.write(
          writer.render_test_file
        )
      end
    end

    def insert_into_existing_file(rendered_test)
      source = absolute_test_file_path.read

      updated =
        RailsProof::TestFileInserter.new(
          source: source,
          test_class_name: test_class_name,
          superclass: superclass
        ).insert(rendered_test)

      absolute_test_file_path.write(updated)
    end

    def persist_review(concern:, test_output:)
      path = review_store.save(
        concern: concern,
        test_output: test_output,
        target_path: target_path,
        test_file_path: test_file_path,
        test_class_name: test_class_name
      )

      [
        path,
        nil
      ]
    rescue StandardError => error
      [
        nil,
        "RailsProof could not persist review: #{error.message}"
      ]
    end

    def runner
      runner_class.new(
        root: root,
        test_file_path: test_file_path
      )
    end
  end
end