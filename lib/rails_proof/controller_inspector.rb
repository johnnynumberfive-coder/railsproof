module RailsProof
  class ControllerInspector
    attr_reader :controller_class, :route_set

    def initialize(controller_class, route_set: Rails.application.routes)
      @controller_class = controller_class
      @route_set = route_set
    end

    def controller_name
      controller_class.name
    end

    def controller_path
      controller_class.controller_path
    end

    def actions
      @actions ||= controller_class.action_methods.sort
    end

    def routes
      @routes ||= route_set.routes.filter_map do |route|
        defaults = route.defaults

        next unless defaults[:controller] == controller_path
        next unless actions.include?(defaults[:action])

        {
          name: route.name,
          verb: route.verb.to_s,
          path: normalize_path(route.path.spec.to_s),
          action: defaults[:action]
        }
      end
    end

    private

    def normalize_path(path)
      path.delete_suffix("(.:format)")
    end
  end
end