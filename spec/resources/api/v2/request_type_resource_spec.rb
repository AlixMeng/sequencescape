# frozen_string_literal: true

require 'rails_helper'
require './app/resources/api/v2/request_type_resource'

RSpec.describe Api::V2::RequestTypeResource, type: :resource do
  let(:resource_model) { create :request_type }
  subject { described_class.new(resource_model, {}) }

  # Test attributes
  it 'works', :aggregate_failures do
    is_expected.to have_attribute :uuid
    is_expected.to have_attribute :name
    is_expected.to have_attribute :key
    is_expected.to have_attribute :for_multiplexing
    is_expected.to_not have_updatable_field(:id)
    is_expected.to_not have_updatable_field(:uuid)
    is_expected.to_not have_updatable_field(:name)
    is_expected.to_not have_updatable_field(:key)
    is_expected.to_not have_updatable_field(:for_multiplexing)
  end

  # Updatable fields
  # eg. it { is_expected.to have_updatable_field(:state) }

  # Filters
  # eg. it { is_expected.to filter(:order_type) }

  # Associations
  # eg. it { is_expected.to have_many(:samples).with_class_name('Sample') }

  # Custom method tests
  # Add tests for any custom methods you've added.
end
