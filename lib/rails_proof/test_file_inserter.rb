module RailsProof
  class TestFileInserter
    class Error < StandardError
    end

    attr_reader :source,
                :test_class_name,
                :superclass

    def initialize(
      source:,
      test_class_name:,
      superclass:
    )
      @source = source
      @test_class_name = test_class_name
      @superclass = superclass
    end

    def insert(rendered_test)
      lines = source.lines

      class_index, class_indent = find_test_class(lines)

      closing_index = find_class_end(
        lines,
        class_index,
        class_indent
      )

      indented_test = indent_rendered_test(
        rendered_test,
        class_indent
      )

      lines.insert(
        closing_index,
        "\n#{indented_test.rstrip}\n"
      )

      lines.join
    end

    private

    def find_test_class(lines)
      exact_name = test_class_name
      short_name = test_class_name.split("::").last

      exact_matches = class_matches(
        lines,
        exact_name
      )

      matches =
        if exact_matches.any?
          exact_matches
        else
          class_matches(
            lines,
            short_name
          )
        end

      if matches.empty?
        raise Error,
              "RailsProof could not find " \
              "#{test_class_name} < #{superclass}"
      end

      if matches.count > 1
        raise Error,
              "RailsProof found multiple candidate " \
              "test classes for #{test_class_name}"
      end

      matches.first
    end

    def class_matches(lines, class_name)
      pattern =
        /\A(?<indent>[ \t]*)class\s+#{Regexp.escape(class_name)}\s*<\s*#{Regexp.escape(superclass)}\s*(?:#.*)?\r?\n?\z/

      lines.each_with_index.filter_map do |line, index|
        match = line.match(pattern)
        next unless match

        [
          index,
          match[:indent]
        ]
      end
    end

    def find_class_end(
      lines,
      class_index,
      class_indent
    )
      pattern =
        /\A#{Regexp.escape(class_indent)}end(?:\s*#.*)?\s*\z/

      closing_index =
        ((class_index + 1)...lines.length).find do |index|
          lines[index].match?(pattern)
        end

      return closing_index if closing_index

      raise Error,
            "RailsProof could not find the end of #{test_class_name}"
    end

    def indent_rendered_test(
      rendered_test,
      class_indent
    )
      lines = rendered_test.rstrip.lines

      nonblank_lines = lines.reject do |line|
        line.strip.empty?
      end

      source_indent =
        nonblank_lines
          .map { |line| line[/\A[ \t]*/].length }
          .min || 0

      target_indent = "#{class_indent}  "

      lines.map do |line|
        if line.strip.empty?
          ""
        else
          content = line[source_indent..]

          "#{target_indent}#{content.rstrip}"
        end
      end.join("\n")
    end
  end
end