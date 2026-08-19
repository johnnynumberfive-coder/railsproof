require "test_helper"
require "tmpdir"
require "generators/rails_proof/test/test_generator"

class RailsProof::RuntimeInspectionResilienceTest <
  Rails::Generators::TestCase

  tests RailsProof::TestGenerator
  destination Rails.root.join(
    "tmp/generators/runtime_inspection_resilience"
  )
  setup :prepare_destination

  test "continues model inspection when constant loading raises" do
    create_target_source(
      "app/models/rails_proof_broken_model.rb",
      <<~RUBY
        class RailsProofBrokenModel < ApplicationRecord
          validates :name, presence: true
        end
      RUBY
    )

    with_broken_autoload(
      :RailsProofBrokenModel,
      "boom while loading model"
    ) do
      output = run_generator(
        ["app/models/rails_proof_broken_model.rb"]
      )

      assert_includes output, "RailsProof targets: 1"
      assert_includes output,
        "Model file: app/models/rails_proof_broken_model.rb"
      assert_includes output, "Source validations: 1"
      assert_includes output, "Runtime inspection: unavailable"
      assert_includes output,
        "Load error: RuntimeError: boom while loading model"
    end

    assert_no_file "test/models/rails_proof_broken_model_test.rb"
  end

  test "continues controller inspection when constant loading raises" do
    create_target_source(
      "app/controllers/rails_proof_broken_controller.rb",
      <<~RUBY
        class RailsProofBrokenController < ApplicationController
          def index
          end
        end
      RUBY
    )

    with_broken_autoload(
      :RailsProofBrokenController,
      "boom while loading controller"
    ) do
      output = run_generator(
        ["app/controllers/rails_proof_broken_controller.rb"]
      )

      assert_includes output, "RailsProof targets: 1"
      assert_includes output,
        "Controller file: app/controllers/rails_proof_broken_controller.rb"
      assert_includes output, "Controller inspection: unavailable"
      assert_includes output,
        "Load error: RuntimeError: boom while loading controller"
    end

    assert_no_file(
      "test/controllers/rails_proof_broken_controller_test.rb"
    )
  end

  private

  def create_target_source(relative_path, source)
    path = Pathname.new(destination_root).join(relative_path)

    path.dirname.mkpath
    path.write(source)
  end

  def with_broken_autoload(constant_name, message)
    Dir.mktmpdir do |directory|
      path = File.join(
        directory,
        "#{constant_name.to_s.underscore}.rb"
      )

      File.write(
        path,
        <<~RUBY
          raise #{message.inspect}
        RUBY
      )

      Object.autoload(constant_name, path)

      yield
    ensure
      if Object.const_defined?(constant_name, false)
        Object.send(:remove_const, constant_name)
      end
    end
  end
end