require "open3"
require "pathname"

module RailsProof
  class TestRunner
    class Error < StandardError; end

    Result = Struct.new(
      :passed,
      :output,
      :command,
      keyword_init: true
    ) do
      def passed?
        passed
      end
    end

    attr_reader :root, :test_file_path

    def initialize(root:, test_file_path:)
      @root = Pathname.new(root).expand_path
      @test_file_path = Pathname.new(test_file_path)
    end

    def run
      stdout, stderr, status = Open3.capture3(
        { "RAILS_ENV" => "test" },
        *command,
        chdir: working_directory.to_s
      )

      Result.new(
        passed: status.success?,
        output: [stdout, stderr].reject(&:empty?).join,
        command: command
      )
    end

    def command
      @command ||= resolve_runner.fetch(:command)
    end

    def working_directory
      @working_directory ||= resolve_runner.fetch(:working_directory)
    end

    private

    def resolve_runner
      @resolve_runner ||= begin
        normal_rails_runner || ancestor_test_runner || raise_runner_error
      end
    end

    def normal_rails_runner
      rails = root.join("bin/rails")
      test_helper = root.join("test/test_helper.rb")

      return unless rails.file? && test_helper.file?

      {
        working_directory: root,
        command: [
          rails.to_s,
          "test",
          test_file_path.to_s
        ]
      }
    end

    def ancestor_test_runner
      current = root

      loop do
        runner = current.join("bin/test")
        test_helper = current.join("test/test_helper.rb")

        if runner.file? && test_helper.file?
          absolute_test_path = root.join(test_file_path).expand_path
          relative_test_path =
            absolute_test_path.relative_path_from(current).to_s

          return {
            working_directory: current,
            command: [
              runner.to_s,
              relative_test_path
            ]
          }
        end

        parent = current.parent
        break if parent == current

        current = parent
      end

      nil
    end

    def raise_runner_error
      raise Error,
        "RailsProof could not find a Rails test runner for #{root}"
    end
  end
end