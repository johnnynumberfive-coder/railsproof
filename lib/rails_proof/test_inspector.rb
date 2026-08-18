module RailsProof
  class TestInspector
    attr_reader :source

    def initialize(source)
      @source = source
    end

    def test_cases
      @test_cases ||= rails_style_tests + method_style_tests
    end

    def count
      test_cases.count
    end

    def empty?
      test_cases.empty?
    end

    private

    def rails_style_tests
      source.each_line.filter_map do |line|
        match = line.match(
          /^\s*test\s*(?:\(\s*)?(["'])(.+?)\1\s*\)?\s+do\b/
        )

        next unless match

        {
          style: :rails,
          name: match[2]
        }
      end
    end

    def method_style_tests
      source.each_line.filter_map do |line|
        match = line.match(/^\s*def\s+(test_[a-zA-Z0-9_!?]+)/)

        next unless match

        method_name = match[1]

        {
          style: :method,
          name: method_name.delete_prefix("test_").tr("_", " "),
          method_name: method_name
        }
      end
    end
  end
end