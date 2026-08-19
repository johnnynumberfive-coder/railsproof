module RailsProof
  class ControllerTestPlan
    attr_reader :inspector

    def initialize(inspector)
      @inspector = inspector
    end

    def concerns
      @concerns ||= inspector.routes.map do |route|
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