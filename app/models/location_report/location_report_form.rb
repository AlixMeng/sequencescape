# frozen_string_literal: true

# This file is part of SEQUENCESCAPE; it is distributed under the terms of
# GNU General Public License version 1 or later;
# Please refer to the LICENSE and README files for information on licensing and
# authorship of this file.
# Copyright (C) 2018 Genome Research Ltd.

##
# This form object class handles the user interaction for creating new Location Reports.
# It sensibility checks the user-entered list of barcode sequences or selection parameters
# before creating the Location Report model.
class LocationReport::LocationReportForm
  include ActiveModel::Model
  include ActiveModel::AttributeMethods

  # Attributes
  attr_accessor :user,
                :report_type,
                :faculty_sponsor_ids,
                :study_id,
                :start_date,
                :end_date,
                :plate_purpose_ids,
                :barcodes,
                :invalid_barcodes,
                :location_report

  attr_reader :barcodes_text,
              :name

  validate :check_for_valid_barcodes, :check_for_invalid_barcodes, :check_location_report

  def initialize(params = nil)
    super
  end

  def barcodes_text=(input_text)
    @barcodes_text = input_text
    parse_barcodes
  end

  def name=(input_name)
    @name = input_name.gsub(/[^A-Za-z0-9_\-\.\s]/, '').squish.gsub(/\s/, '_') if input_name.present?
    @name = Time.current.to_formatted_s(:number) if input_name.blank?
  end

  def save
    fetch_or_create_location_report.save if valid?
  end

  # form builder methods (e.g. form_to) need the Active Model name to be set
  def self.model_name
    ActiveModel::Name.new(LocationReport)
  end

  #######

  private

  #######

  def fetch_or_create_location_report
    return location_report unless location_report.nil?
    self.location_report = LocationReport.new(
      user: user,
      name: name,
      report_type: report_type,
      faculty_sponsor_ids: faculty_sponsor_ids,
      study_id: study_id,
      start_date: start_date&.to_datetime,
      end_date: end_date&.to_datetime,
      plate_purpose_ids: plate_purpose_ids,
      barcodes: barcodes
    )
  end

  def parse_barcodes
    @invalid_barcodes = []
    valid_barcodes_hash = {}
    parsed_barcodes.each do |cur_bc|
      if barcode_is_human_readable?(cur_bc)
        begin
          cur_bc = Barcode.human_to_machine_barcode(cur_bc).to_s
          check_barcode_is_unique(valid_barcodes_hash, cur_bc)
        rescue SBCF::InvalidBarcode
          invalid_barcodes << cur_bc
        end
      elsif barcode_is_ean13?(cur_bc)
        check_barcode_is_unique(valid_barcodes_hash, cur_bc)
      else
        invalid_barcodes << cur_bc
      end
    end
    @barcodes ||= valid_barcodes_hash.keys if valid_barcodes_hash.present?
  end

  def parsed_barcodes
    barcodes_text&.squish&.split(/[\s\,]+/) || []
  end

  def check_for_valid_barcodes
    return if barcodes_text.blank?
    errors.add(:barcodes_text, I18n.t('location_reports.errors.no_valid_barcodes_found')) if barcodes.blank?
  end

  def check_for_invalid_barcodes
    return if barcodes_text.blank?
    errors.add(:barcodes_text, I18n.t('location_reports.errors.invalid_barcodes_found') + invalid_barcodes.join(',')) if invalid_barcodes.present?
  end

  def check_barcode_is_unique(valid_barcodes, cur_bc)
    if valid_barcodes.key?(cur_bc)
      errors.add(:base, I18n.t('location_reports.errors.duplicate_barcode_found') + cur_bc)
    else
      valid_barcodes[cur_bc] = 1
    end
  end

  def check_location_report
    return if fetch_or_create_location_report.valid?
    add_location_errors
  end

  def add_location_errors
    return if location_report.nil?
    location_report.errors.each do |key, value|
      errors.add key, value
    end
  end

  def barcode_is_human_readable?(barcode)
    barcode.match?(SBCF::HUMAN_BARCODE_FORMAT)
  end

  def barcode_is_ean13?(barcode)
    barcode.match?(SBCF::MACHINE_BARCODE_FORMAT)
  end
end
