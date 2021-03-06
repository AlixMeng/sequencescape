# frozen_string_literal: true

module SequencescapeExcel
  module SpecialisedField
    ##
    # Tag2Group
    class Tag2Group
      include Base

      validate :check_tag2_group

      def tag2_group_id
        @tag2_group_id ||= ::TagGroup.find_by(name: value)&.id
      end

      private

      # check the group exists here, check the group/index combination in tag2_index
      def check_tag2_group
        return if tag2_group_id.present?

        errors.add(:base, "could not find a tag2 group with name #{value}.")
      end
    end
  end
end
