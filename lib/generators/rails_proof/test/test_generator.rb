require "pathname"
require "rails_proof/model_inspector"
require "rails_proof/model_test_plan"
require "rails_proof/test_inspector"
require "rails_proof/test_coverage_plan"
require "rails_proof/test_writer"
require "rails_proof/target_discovery"
require "rails_proof/controller_inspector"
require "rails_proof/controller_test_plan"
require "rails_proof/controller_test_coverage_plan"
require "rails_proof/controller_test_writer"
require "rails_proof/ai_test_planner"
require "rails_proof/ai_test_executor"

module RailsProof
  class TestGenerator < Rails::Generators::Base
    ASSOCIATION_MACROS = %w[
      belongs_to
      has_many
      has_one
      has_and_belongs_to_many
    ].freeze

    argument :scope,
      type: :string,
      required: false,
      banner: "[app/models/post.rb|app/models|app/controllers]"

    def run_rails_proof
      say "RailsProof targets: #{targets.count}"

      if targets.empty?
        say "No supported targets found."
        return
      end

      targets.each_with_index do |target, index|
        say "" if index.positive?
        process_target(target)
      end
    end

    private

    def targets
      @targets ||= RailsProof::TargetDiscovery.new(
        root: destination_root,
        scope: scope
      ).targets
    rescue ArgumentError => error
      raise Thor::Error, error.message
    end

    def process_target(target)
      case target.type
      when :model
        process_model(target)
      when :controller
        process_controller(target)
      else
        say "Unsupported target type: #{target.type}"
      end
    end

    def process_model(target)
      prepare_model_target(target)

      say "RailsProof inspection"
      say "Model file: #{@current_target.path}"
      say "Model class: #{@current_target.class_name}"
      say "Test file: #{@test_file_path}"
      say "Test status: #{test_file_status}"
      say "Test cases: #{@test_inspector.count}" if @absolute_test_file_path.file?

      report_source_analysis
      report_runtime_analysis

      if @model_class
        concerns = report_ai_analysis(
          target_type: :model,
          class_name: @current_target.class_name,
          source: @model_source,
          deterministic_concerns: @model_test_plan.concerns
        )

        execute_ai_tests(
          concerns: concerns,
          test_class_name: "#{@current_target.class_name}Test",
          superclass: "ActiveSupport::TestCase"
        )
      end

      write_missing_tests
    end

    def prepare_model_target(target)
      @current_target = target
      @model_class = target.class_name.safe_constantize
      @absolute_model_path = Pathname.new(destination_root).join(target.path)
      @model_source = @absolute_model_path.read

      model_name = target.path
        .delete_prefix("app/models/")
        .delete_suffix(".rb")

      prepare_test_target("test/models/#{model_name}_test.rb")

      if @model_class
        @runtime_inspector = RailsProof::ModelInspector.new(@model_class)
        @model_test_plan = RailsProof::ModelTestPlan.new(@runtime_inspector)
        @coverage_plan = RailsProof::TestCoveragePlan.new(
          @model_test_plan,
          @test_inspector
        )
      else
        @runtime_inspector = nil
        @model_test_plan = nil
        @coverage_plan = nil
      end
    end

    def process_controller(target)
      prepare_controller_target(target)

      say "RailsProof inspection"
      say "Controller file: #{@current_target.path}"
      say "Controller class: #{@current_target.class_name}"
      say "Test file: #{@test_file_path}"
      say "Test status: #{test_file_status}"
      say "Test cases: #{@test_inspector.count}" if @absolute_test_file_path.file?

      report_controller_analysis

      if @controller_class
        concerns = report_ai_analysis(
          target_type: :controller,
          class_name: @current_target.class_name,
          source: @controller_source,
          deterministic_concerns: @controller_test_plan.concerns
        )

        execute_ai_tests(
          concerns: concerns,
          test_class_name: "#{@current_target.class_name}Test",
          superclass: "ActionDispatch::IntegrationTest"
        )
      end

      write_missing_controller_tests
    end

    def prepare_controller_target(target)
      @current_target = target
      @controller_class = target.class_name.safe_constantize
      @absolute_controller_path =
        Pathname.new(destination_root).join(target.path)
      @controller_source = @absolute_controller_path.read

      controller_name = target.path
        .delete_prefix("app/controllers/")
        .delete_suffix(".rb")

      prepare_test_target(
        "test/controllers/#{controller_name}_test.rb"
      )

      if @controller_class
        @controller_inspector = RailsProof::ControllerInspector.new(
          @controller_class
        )
        @controller_test_plan = RailsProof::ControllerTestPlan.new(
          @controller_inspector
        )
        @controller_coverage_plan =
          RailsProof::ControllerTestCoveragePlan.new(
            @controller_test_plan,
            @test_inspector
          )
      else
        @controller_inspector = nil
        @controller_test_plan = nil
        @controller_coverage_plan = nil
      end
    end

    def prepare_test_target(test_file_path)
      @test_file_path = test_file_path
      @absolute_test_file_path =
        Pathname.new(destination_root).join(@test_file_path)

      @test_source = if @absolute_test_file_path.file?
        @absolute_test_file_path.read
      else
        ""
      end

      @test_inspector = RailsProof::TestInspector.new(@test_source)
    end

    def test_file_status
      @absolute_test_file_path.file? ? "exists" : "missing"
    end

    def association_declarations
      @model_source.each_line.filter_map do |line|
        declaration = line.strip

        declaration if ASSOCIATION_MACROS.any? do |macro|
          declaration.match?(/\A#{macro}\s+/)
        end
      end
    end

    def validation_declarations
      @model_source.each_line.filter_map do |line|
        declaration = line.strip

        declaration if declaration.match?(/\Avalidates\s+/)
      end
    end

    def report_source_analysis
      associations = association_declarations
      validations = validation_declarations

      say "Source associations: #{associations.count}"
      associations.each do |declaration|
        say "  #{declaration}"
      end

      say "Source validations: #{validations.count}"
      validations.each do |declaration|
        say "  #{declaration}"
      end
    end

    def report_runtime_analysis
      unless @model_class
        say "Runtime inspection: unavailable"
        return
      end

      say "Runtime inspection: available"
      say "Table: #{@runtime_inspector.table_name}"

      report_runtime_columns
      report_runtime_associations
      report_runtime_validators
      report_test_plan
      report_coverage
    end

    def report_runtime_columns
      columns = @runtime_inspector.columns

      say "Columns: #{columns.count}"
      columns.each do |column|
        say(
          "  #{column[:name]} #{column[:type]} " \
          "null=#{column[:null]} default=#{column[:default].inspect}"
        )
      end
    rescue ActiveRecord::StatementInvalid => error
      say "Columns: unavailable (#{error.message.lines.first.strip})"
    end

    def report_runtime_associations
      associations = @runtime_inspector.associations

      say "Runtime associations: #{associations.count}"
      associations.each do |association|
        say(
          "  #{association[:macro]} :#{association[:name]} " \
          "class=#{association[:class_name]} " \
          "foreign_key=#{association[:foreign_key]}"
        )
      end
    end

    def report_runtime_validators
      validators = @runtime_inspector.validators

      say "Runtime validators: #{validators.count}"
      validators.each do |validator|
        say(
          "  #{validator[:class_name]} " \
          "attributes=#{validator[:attributes].inspect}"
        )
      end
    end

    def report_test_plan
      say "Suggested tests: #{@model_test_plan.count}"
      @model_test_plan.concerns.each do |concern|
        say "  #{concern[:description]}"
      end
    end

    def report_coverage
      say "Coverage:"
      say "  Covered: #{@coverage_plan.covered_count}"
      say "  Missing: #{@coverage_plan.missing_count}"

      @coverage_plan.missing_concerns.each do |concern|
        say "    #{concern[:description]}"
      end
    end

    def report_controller_analysis
      unless @controller_class
        say "Controller inspection: unavailable"
        return
      end

      say "Controller inspection: available"

      say "Actions: #{@controller_inspector.actions.count}"
      @controller_inspector.actions.each do |action|
        say "  #{action}"
      end

      say "Routes: #{@controller_inspector.routes.count}"
      @controller_inspector.routes.each do |route|
        say "  #{route[:verb]} #{route[:path]} -> #{route[:action]}"
      end

      say "Suggested tests: #{@controller_test_plan.count}"
      @controller_test_plan.concerns.each do |concern|
        say "  #{concern[:description]}"
      end

      say "Coverage:"
      say "  Covered: #{@controller_coverage_plan.covered_count}"
      say "  Missing: #{@controller_coverage_plan.missing_count}"

      @controller_coverage_plan.missing_concerns.each do |concern|
        say "    #{concern[:description]}"
      end
    end

    def report_ai_analysis(
      target_type:,
      class_name:,
      source:,
      deterministic_concerns:
    )
      planner = RailsProof::AiTestPlanner.new(
        target_type: target_type,
        class_name: class_name,
        source: source,
        existing_tests: @test_source,
        deterministic_concerns: deterministic_concerns,
        client: RailsProof.ai_client
      )

      concerns = planner.concerns

      say "AI suggested tests: #{concerns.count}"

      concerns.each do |concern|
        say "  #{concern[:name]}"
        say "    Reason: #{concern[:reason]}"

        next unless concern[:test_code]

        say "    Candidate test:"

        concern[:test_code].each_line do |line|
          say "      #{line.chomp}"
        end
      end

      concerns
    rescue RailsProof::AiTestPlanner::InvalidResponse,
      RailsProof::OpenAiClient::Error => error
      raise Thor::Error,
        "RailsProof AI analysis failed: #{error.message}"
    end

    def execute_ai_tests(
      concerns:,
      test_class_name:,
      superclass:
    )
      if concerns.empty?
        say "AI test results: 0"
        return
      end

      executor = RailsProof::AiTestExecutor.new(
        root: destination_root,
        test_file_path: @test_file_path,
        test_class_name: test_class_name,
        superclass: superclass,
        concerns: concerns
      )

      results = executor.execute

      say "AI test results: #{results.count}"

      results.each do |result|
        if result.kept?
          say "  KEPT: #{result.concern[:name]}"
        else
          say "  REJECTED: #{result.concern[:name]}"

          result.errors.each do |error|
            say "    #{error}"
          end

          report_failed_test_output(result.test_output)
        end
      end
    end

    def report_failed_test_output(output)
      return if output.blank?

      say "    Test output:"

      output.each_line do |line|
        say "      #{line.chomp}"
      end
    end

    def write_missing_tests
      return unless @model_class
      return if @coverage_plan.missing_count.zero?

      writer = RailsProof::TestWriter.new(
        model_class_name: @current_target.class_name,
        concerns: @coverage_plan.missing_concerns
      )

      if @absolute_test_file_path.file?
        inject_into_file(
          @test_file_path,
          "\n#{writer.render}\n",
          before: /^end\s*\z/
        )
      else
        create_file @test_file_path, writer.render_test_file
      end
    end

    def write_missing_controller_tests
      return unless @controller_class
      return if @controller_coverage_plan.missing_count.zero?

      writer = RailsProof::ControllerTestWriter.new(
        controller_class_name: @current_target.class_name,
        concerns: @controller_coverage_plan.missing_concerns
      )

      if @absolute_test_file_path.file?
        inject_into_file(
          @test_file_path,
          "\n#{writer.render}\n",
          before: /^end\s*\z/
        )
      else
        create_file @test_file_path, writer.render_test_file
      end
    end
  end
end