module RailsProof
  class ControllerTestWriter
    attr_reader :controller_class_name, :concerns

    def initialize(controller_class_name:, concerns:)
      @controller_class_name = controller_class_name
      @concerns = concerns
    end

    def render
      concerns.map do |concern|
        indent(render_concern(concern), 2)
      end.join("\n\n")
    end

    def render_test_file
      [
        'require "test_helper"',
        "",
        "class #{controller_class_name}Test < ActionDispatch::IntegrationTest",
        render,
        "end",
        ""
      ].join("\n")
    end

    private

    def render_concern(concern)
      case concern[:type]
      when :controller_response
        render_response_test(concern)
      else
        raise ArgumentError,
          "Unsupported controller test concern: #{concern.inspect}"
      end
    end

    def render_response_test(concern)
      verb = concern.fetch(:verb).downcase
      route_name = concern.fetch(:route_name)
      action = concern.fetch(:action)

      unless route_name
        raise ArgumentError,
          "Cannot generate controller test without a named route: #{concern.inspect}"
      end

      <<~RUBY.chomp
        test "should #{verb} #{action}" do
          #{verb} #{route_name}_url

          assert_response :success
        end
      RUBY
    end

    def indent(source, spaces)
      prefix = " " * spaces

      source.lines.map do |line|
        line.strip.empty? ? line : "#{prefix}#{line}"
      end.join
    end
  end
end