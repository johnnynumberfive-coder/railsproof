require "pathname"

module RailsProof
  class TestGenerator < Rails::Generators::Base
    ASSOCIATION_MACROS = %w[
      belongs_to
      has_many
      has_one
      has_and_belongs_to_many
    ].freeze

    argument :model_path,
      type: :string,
      required: true,
      banner: "app/models/user.rb"

    def inspect_model
      validate_model_path!

      say "RailsProof inspection"
      say "Model file: #{relative_model_path}"
      say "Model class: #{model_class_name}"
      say "Test file: #{test_file_path}"
      say "Test status: #{test_file_status}"
      say "Test cases: #{test_case_count}" if absolute_test_file_path.file?

      say "Associations: #{association_declarations.count}"
      association_declarations.each do |declaration|
        say "  #{declaration}"
      end

      say "Validations: #{validation_declarations.count}"
      validation_declarations.each do |declaration|
        say "  #{declaration}"
      end
    end

    private

    def relative_model_path
      @relative_model_path ||= Pathname.new(model_path).cleanpath.to_s
    end

    def absolute_model_path
      @absolute_model_path ||= Pathname.new(destination_root).join(relative_model_path)
    end

    def validate_model_path!
      unless relative_model_path.start_with?("app/models/") &&
          relative_model_path.end_with?(".rb")
        raise Thor::Error,
          "Expected a Rails model path under app/models, got: #{model_path}"
      end

      return if absolute_model_path.file?

      raise Thor::Error, "Model file not found: #{relative_model_path}"
    end

    def model_name
      @model_name ||= relative_model_path
        .delete_prefix("app/models/")
        .delete_suffix(".rb")
    end

    def model_class_name
      model_name.camelize
    end

    def test_file_path
      "test/models/#{model_name}_test.rb"
    end

    def absolute_test_file_path
      @absolute_test_file_path ||= Pathname.new(destination_root).join(test_file_path)
    end

    def test_file_status
      absolute_test_file_path.file? ? "exists" : "missing"
    end

    def test_case_count
      test_source.scan(/^\s*test\s+["'][^"']+["']\s+do\b/).count +
        test_source.scan(/^\s*def\s+test_\w+/).count
    end

    def model_source
      @model_source ||= absolute_model_path.read
    end

    def test_source
      @test_source ||= absolute_test_file_path.read
    end

    def association_declarations
      @association_declarations ||= model_source.each_line.filter_map do |line|
        declaration = line.strip

        declaration if ASSOCIATION_MACROS.any? do |macro|
          declaration.match?(/\A#{macro}\s+/)
        end
      end
    end

    def validation_declarations
      @validation_declarations ||= model_source.each_line.filter_map do |line|
        declaration = line.strip

        declaration if declaration.match?(/\Avalidates\s+/)
      end
    end
  end
end