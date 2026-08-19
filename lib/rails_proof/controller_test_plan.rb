module RailsProof
  class ControllerTestPlan
    attr_reader :inspector

    def initialize(inspector)
      @inspector = inspector
    end

    def concerns
      @concerns ||= inspector.routes.filter_map do |route|
        next if route[:name].to_s.empty?

        {
          type: :controller_response,
          verb: route[:verb],
          path: route[:path],
          route_name: route[:name],
          action: route[:action],
          description: "#{route[:verb]} #{route[:path]} responds successfully"
        }
      end
    end

    def count
      concerns.count
    end
  end
end