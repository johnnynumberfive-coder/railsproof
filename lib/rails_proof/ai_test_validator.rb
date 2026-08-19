require "ripper"

module RailsProof
  class AiTestValidator
    Result = Struct.new(
      :valid,
      :errors,
      keyword_init: true
    ) do
      def valid?
        valid
      end
    end

    attr_reader :test_code

    def initialize(test_code)
      @test_code = test_code
    end

    def validate
      errors = []

      errors << "test code must be a nonblank string" unless nonblank?
      return Result.new(valid: false, errors: errors) unless errors.empty?

      errors << "test code is not valid Ruby" unless valid_ruby?
      errors << "test code must contain exactly one test declaration" unless one_test?
      errors << "test code must not contain a class declaration" if class_declaration?
      errors << "test code must not contain a require statement" if require_statement?
      errors << "test code must not contain Markdown code fences" if markdown_fence?

      Result.new(
        valid: errors.empty?,
        errors: errors
      )
    end

    private

    def nonblank?
      test_code.is_a?(String) && !test_code.strip.empty?
    end

    def valid_ruby?
      !Ripper.sexp(test_code).nil?
    end

    def one_test?
      test_code.scan(/^\s*test\s*(?:\(\s*)?["']/).count == 1
    end

    def class_declaration?
      test_code.match?(/^\s*class\s+/)
    end

    def require_statement?
      test_code.match?(/^\s*require(?:_relative)?\s+/)
    end

    def markdown_fence?
      test_code.include?("```")
    end
  end
end