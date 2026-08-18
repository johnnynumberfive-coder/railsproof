module RailsProof
  class ModelInspector
    attr_reader :model_class

    def initialize(model_class)
      @model_class = model_class
    end

    def model_name
      model_class.name
    end

    def table_name
      model_class.table_name
    end

    def columns
      @columns ||= model_class.columns.map do |column|
        {
          name: column.name,
          type: column.type,
          null: column.null,
          default: column.default
        }
      end
    end

    def associations
      @associations ||= model_class.reflect_on_all_associations.map do |association|
        {
          macro: association.macro,
          name: association.name,
          class_name: association.class_name,
          foreign_key: association.foreign_key,
          options: association.options
        }
      end
    end

    def validators
      @validators ||= model_class.validators.map do |validator|
        {
          class_name: validator.class.name,
          attributes: validator.attributes,
          options: validator.options
        }
      end
    end
  end
end