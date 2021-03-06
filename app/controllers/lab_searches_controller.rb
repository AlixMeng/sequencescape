class LabSearchesController < ApplicationController
  include SearchBehaviour
  alias_method(:new, :search)

  def index
    redirect_to action: :new
  end

  private

  def perform_search(query)
    @batches = Batch.for_search_query(query).to_a
    @assets = (
                Asset.for_search_query(query).for_lab_searches_display.to_a +
                Asset.with_barcode(query).for_lab_searches_display.to_a
              ).uniq
  end
end
