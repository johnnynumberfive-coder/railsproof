module RailsProof
  class TestWriter
    attr_reader :model_class_name, :concerns

    def initialize(model_class_name:, concerns:)
      @model_class_name = model_class_name
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
        "class #{model_class_name}Test < ActiveSupport::TestCase",
        render,
        "end",
        ""
      ].join("\n")
    end

    private

    def render_concern(concern)
      case concern[:type]
      when :association
        render_association(concern)
      when :validation
        render_validation(concern)
      else
        raise ArgumentError, "Unsupported test concern: #{concern.inspect}"
      end
    end

    def render_association(concern)
      macro = concern.fetch(:macro)
      name = concern.fetch(:name)
      test_name = "#{macro.to_s.tr("_", " ")} #{name}"

      <<~RUBY.chomp
        test "#{test_name}" do
          association = #{model_class_name}.reflect_on_association(:#{name})

          assert_not_nil association
          assert_equal :#{macro}, association.macro
        end
      RUBY
    end

    def render_validation(concern)
      validation = concern.fetch(:validation)
      attribute = concern.fetch(:attribute)

      case validation
      when :presence
        render_presence_validation(attribute)
      else
        raise ArgumentError, "Unsupported validation: #{validation.inspect}"
      end
    end

    def render_presence_validation(attribute)
      <<~RUBY.chomp
        test "validates presence of #{attribute}" do
          record = #{model_class_name}.new(#{attribute}: nil)

          record.validate

          assert record.errors.of_kind?(:#{attribute}, :blank)
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