# This file is part of SEQUENCESCAPE; it is distributed under the terms of
# GNU General Public License version 1 or later;
# Please refer to the LICENSE and README files for information on licensing and
# authorship of this file.
# Copyright (C) 2007-2011,2012,2013,2014,2015,2016 Genome Research Ltd.

# A barcode is an identifier for a piece of labware which is attached via a
# printed label. Barcodes may either be generated by Sequencescape, or may get
# supplied externally. In some cases labware may have more than one barcode assigned.
#
# @author [grl]
#
class Barcode < ApplicationRecord
  require 'sanger_barcode_format'
  require 'sanger_barcode_format/legacy_methods'
  extend SBCF::LegacyMethods

  belongs_to :asset, required: true
  before_validation :serialize_barcode

  after_commit :broadcast_barcode

  # Caution! Do not adjust the index of existing formats.
  enum format: [:sanger_ean13, :infinium, :fluidigm, :external, :cgap]

  FOREIGN_BARCODE_FORMATS = %i[cgap].freeze

  validate :barcode_valid?

  scope(:sanger_barcode, lambda do |prefix, number|
    human_barcode = SBCF::SangerBarcode.from_prefix_and_number(prefix, number).human_barcode
    where(format: :sanger_ean13, barcode: human_barcode)
  end)

  delegate_missing_to :handler

  def self.build_sanger_ean13(attributes)
    # We need to symbolize our hash keys to allow them to get passed in to named arguments.
    safe_attributes = attributes.slice(:number, :prefix, :human_barcode, :machine_barcode).symbolize_keys
    new(format: :sanger_ean13, barcode: SBCF::SangerBarcode.new(safe_attributes).human_barcode)
  end

  # Extract barcode from user input
  def self.extract_barcode(barcode)
    [barcode.to_s].tap do |barcodes|
      barcodes << SBCF::SangerBarcode.from_user_input(barcode.to_s).human_barcode
    end.compact.uniq
  end

  # check if a given barcode string matches any foreign barcode format
  def self.matches_any_foreign_barcode_format?(possible_barcode)
    FOREIGN_BARCODE_FORMATS.each do |cur_format|
      bc = Barcode.new(format: cur_format, barcode: possible_barcode)
      return cur_format if bc.handler.valid?
    end
    nil
  end

  def self.unique_for_format?(barcode_format, search_barcode)
    return unless barcode_format.present? && search_barcode.present?
    Barcode.find_by(format: barcode_format, barcode: search_barcode)
  end

  def handler
    @handler ||= handler_class.new(barcode)
  end

  def handler_class_name
    format.classify
  end

  # If the barcode changes, we'll need a new handler. This allows handlers themselves to be immutable.
  def barcode=(new_barcode)
    @handler = nil
    super
  end

  private

  def barcode_valid?
    errors.add(:barcode, "is not an acceptable #{format} barcode") unless handler.valid?
  end

  def handler_class
    Barcode::FormatHandlers.const_get(handler_class_name, false)
  end

  def broadcast_barcode
    Messenger.new(template: 'BarcodeIO', root: 'barcode', target: self).broadcast
  end
end
