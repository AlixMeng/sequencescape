class Api::ReferenceGenomeIO < Api::Base
  module Extensions
    module ClassMethods
      def render_class
        Api::ReferenceGenomeIO
      end
    end

    def self.included(base)
      base.class_eval do
        extend ClassMethods
      end
    end

    def json_root
      'reference_genome'
    end
  end

  renders_model(::ReferenceGenome)

  map_attribute_to_json_attribute(:uuid)
  map_attribute_to_json_attribute(:id, 'internal_id')
  map_attribute_to_json_attribute(:name)
  map_attribute_to_json_attribute(:created_at)
  map_attribute_to_json_attribute(:updated_at)
end
