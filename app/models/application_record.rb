class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # The frontend (TypeScript/React) speaks camelCase; the database speaks
  # snake_case. Translate at the JSON boundary so every model serializes
  # consistently without per-controller mapping.
  def as_json(options = {})
    super(options).transform_keys { |key| key.camelize(:lower) }
  end
end
