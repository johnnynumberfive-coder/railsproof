module RailsProof
  class ModelTestPlan
    attr_reader :inspector

    def initialize(inspector)
      @inspector = inspector
    end

    def concerns
      @concerns ||= association_concerns + validation_concerns
    end

    def count
      concerns.count
    end

    private

    def association_concerns
      inspector.associations.map do |association|
        {
          type: :association,
          macro: association[:macro],
          name: association[:name],
          description: "#{association[:macro]} :#{association[:name]}"
        }
      end
    end

    def validation_concerns
      inspector.validators.flat_map do |validator|
        next [] unless presence_validator?(validator)

        validator[:attributes].filter_map do |attribute|
          next if implicit_belongs_to_presence?(attribute)

          {
            type: :validation,
            validation: :presence,
            attribute: attribute,
            description: "validates presence of #{attribute}"
          }
        end
      end
    end

    def presence_validator?(validator)
      validator[:class_name].end_with?("PresenceValidator")
    end

    def implicit_belongs_to_presence?(attribute)
      belongs_to_association_names.include?(attribute)
    end

    def belongs_to_association_names
      @belongs_to_association_names ||= inspector.associations.filter_map do |association|
        association[:name] if association[:macro] == :belongs_to
      end
    end
  end
end