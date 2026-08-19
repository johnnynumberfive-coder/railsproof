module RailsProof
  class AiTestWriter
    class InvalidConcern < StandardError; end

    attr_reader :test_class_name, :superclass, :concerns

    def initialize(test_class_name:, superclass:, concerns:)
      @test_class_name = test_class_name
      @superclass = superclass
      @concerns = concerns
    end

    def render
      concerns.map do |concern|
        indent(test_code_for(concern), 2)
      end.join("\n\n")
    end

    def render_test_file
      [
        'require "test_helper"',
        "",
        "class #{test_class_name} < #{superclass}",
        render,
        "end",
        ""
      ].join("\n")
    end

    private

    def test_code_for(concern)
      code = concern[:test_code] || concern["test_code"]

      unless code.is_a?(String) && code.strip.present?
        raise InvalidConcern,
          "AI test concern must include test_code"
      end

      code.strip
    end

    def indent(source, spaces)
      prefix = " " * spaces

      source.lines.map do |line|
        line.strip.empty? ? line : "#{prefix}#{line}"
      end.join
    end
  end
end