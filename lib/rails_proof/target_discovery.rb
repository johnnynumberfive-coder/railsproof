require "pathname"
require "active_support/core_ext/string/inflections"

module RailsProof
  class TargetDiscovery
    Target = Struct.new(
      :type,
      :path,
      :class_name,
      keyword_init: true
    )

    SUPPORTED_DIRECTORIES = {
      "app/models" => :model,
      "app/controllers" => :controller
    }.freeze

    attr_reader :root, :scope

    def initialize(root:, scope: nil)
      @root = Pathname.new(root)
      @scope = scope
    end

    def targets
      @targets ||= if normalized_scope
        discover_scope(normalized_scope)
      else
        discover_all
      end
    end

    private

    def normalized_scope
      return @normalized_scope if defined?(@normalized_scope)

      value = scope.to_s.strip

      @normalized_scope = if value.empty?
        nil
      else
        normalize_path(value)
      end
    end

    def normalize_path(path)
      pathname = Pathname.new(path)

      if pathname.absolute?
        raise ArgumentError, "RailsProof scope must be relative to the Rails application"
      end

      normalized = pathname.cleanpath.to_s.delete_prefix("./")

      if normalized == ".." || normalized.start_with?("../")
        raise ArgumentError, "RailsProof scope must stay inside the Rails application"
      end

      normalized
    end

    def discover_scope(path)
      absolute_path = root.join(path)

      if absolute_path.file?
        [target_for_file(path)]
      elsif absolute_path.directory?
        discover_directory(path)
      else
        raise ArgumentError, "RailsProof target not found: #{path}"
      end
    end

    def discover_all
      SUPPORTED_DIRECTORIES.keys.flat_map do |directory|
        next [] unless root.join(directory).directory?

        discover_directory(directory)
      end
    end

    def discover_directory(directory)
      type = type_for_path(directory)

      unless type
        raise ArgumentError, "Unsupported RailsProof target: #{directory}"
      end

      pattern = root.join(directory, "**", "*.rb").to_s

      Dir.glob(pattern).sort.filter_map do |absolute_path|
        relative_path = Pathname.new(absolute_path)
          .relative_path_from(root)
          .to_s

        next if ignored_path?(relative_path)

        target_for_file(relative_path)
      end
    end

    def target_for_file(path)
      type = type_for_path(path)

      unless type && path.end_with?(".rb")
        raise ArgumentError, "Unsupported RailsProof target: #{path}"
      end

      if ignored_path?(path)
        raise ArgumentError, "RailsProof does not inspect base or concern files: #{path}"
      end

      Target.new(
        type: type,
        path: path,
        class_name: class_name_for(path, type)
      )
    end

    def type_for_path(path)
      SUPPORTED_DIRECTORIES.each do |directory, type|
        return type if path == directory || path.start_with?("#{directory}/")
      end

      nil
    end

    def ignored_path?(path)
      path == "app/models/application_record.rb" ||
        path.start_with?("app/models/concerns/") ||
        path == "app/controllers/application_controller.rb" ||
        path.start_with?("app/controllers/concerns/")
    end

    def class_name_for(path, type)
      prefix = type == :model ? "app/models/" : "app/controllers/"

      path
        .delete_prefix(prefix)
        .delete_suffix(".rb")
        .camelize
    end
  end
end