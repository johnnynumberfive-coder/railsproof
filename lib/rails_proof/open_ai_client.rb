require "json"

module RailsProof
  class OpenAiClient
    class Error < StandardError; end

    DEFAULT_MODEL = "gpt-5.6"

    RESPONSE_SCHEMA = {
      type: :object,
      properties: {
        suggestions: {
          type: :array,
          items: {
            type: :object,
            properties: {
              name: { type: :string },
              reason: { type: :string },
              test_code: { type: :string }
            },
            required: %w[name reason test_code],
            additionalProperties: false
          }
        }
      },
      required: %w[suggestions],
      additionalProperties: false
    }.freeze

    attr_reader :model

    def initialize(
      model: ENV.fetch("RAILSPROOF_OPENAI_MODEL", DEFAULT_MODEL),
      sdk_client: nil
    )
      @model = model
      @sdk_client = sdk_client
    end

    def suggest_tests(context:)
      response = client.responses.create(
        model: model,
        input: [
          {
            role: :system,
            content: system_prompt
          },
          {
            role: :user,
            content: JSON.generate(context)
          }
        ],
        text: {
          format: {
            type: :json_schema,
            name: "rails_proof_test_suggestions",
            strict: true,
            schema: RESPONSE_SCHEMA
          }
        }
      )

      parse_suggestions(response.output_text)
    rescue Error
      raise
    rescue StandardError => error
      raise Error, "OpenAI request failed: #{error.message}"
    end

    private

    def client
      @sdk_client ||= begin
        require "openai"

        OpenAI::Client.new
      rescue LoadError
        raise Error,
          "OpenAI client is not installed. Add the openai gem to use AI planning."
      end
    end

    def system_prompt
      <<~PROMPT
        You are RailsProof's AI test planner and Minitest test generator.

        Analyze Rails 8.1+ application code for meaningful Minitest coverage
        that deterministic Rails inspection cannot already identify.

        Suggest only additional tests justified by the supplied source and
        runtime context.

        Do not duplicate deterministic concerns RailsProof already identified.

        Do not suggest behavior that is already adequately covered by the
        supplied existing tests.

        Do not invent application behavior unsupported by the source.

        Focus especially on:
        - branches and conditional behavior
        - custom public methods
        - edge cases
        - nil and blank handling
        - state transitions
        - persistence behavior
        - side effects
        - error conditions
        - interactions between application objects

        For every suggestion, generate the actual Minitest code needed to
        exercise that behavior.

        Each suggestion must have:
        - name: a concise Minitest-style test description
        - reason: why that behavior deserves a test
        - test_code: exactly one complete Minitest test block

        test_code must:
        - begin with a Minitest test declaration
        - contain exactly one test block
        - be valid Ruby
        - contain no class declaration
        - contain no require statement
        - contain no Markdown code fences
        - use only application behavior supported by the supplied context
        - avoid assuming fixtures, factories, helpers, or methods not shown
          in the supplied context
      PROMPT
    end

    def parse_suggestions(output_text)
      parsed = JSON.parse(output_text)
      suggestions = parsed.fetch("suggestions")

      unless suggestions.is_a?(Array)
        raise Error, "OpenAI response suggestions must be an array"
      end

      suggestions
    rescue JSON::ParserError, KeyError => error
      raise Error, "Invalid OpenAI response: #{error.message}"
    end
  end
end