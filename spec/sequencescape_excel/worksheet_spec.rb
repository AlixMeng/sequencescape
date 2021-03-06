# frozen_string_literal: true

require 'rails_helper'
require 'pry'

RSpec.describe SequencescapeExcel::Worksheet, type: :model, sample_manifest_excel: true do
  attr_reader :sample_manifest, :spreadsheet

  let(:xls) { Axlsx::Package.new }
  let(:workbook) { xls.workbook }
  let(:test_file) { 'test.xlsx' }

  def save_file
    xls.serialize(test_file)
    @spreadsheet = Roo::Spreadsheet.open(test_file)
  end

  before(:all) do
    SampleManifestExcel.configure do |config|
      config.folder = File.join('spec', 'data', 'sample_manifest_excel')
      config.load!
    end
  end

  before(:each) do
    barcode = double('barcode')
    allow(barcode).to receive(:barcode).and_return(23)
    allow(PlateBarcode).to receive(:create).and_return(barcode)

    @sample_manifest = create :sample_manifest, rapid_generation: true
    sample_manifest.generate
  end

  context 'validations ranges worksheet' do
    let!(:range_list) { SampleManifestExcel.configuration.ranges.dup }
    let!(:worksheet) { SequencescapeExcel::Worksheet::RangesWorksheet.new(workbook: workbook, ranges: range_list) }

    before(:each) do
      save_file
    end

    it 'has a axlsx worksheet' do
      expect(worksheet.axlsx_worksheet).to be_present
    end

    it 'will add ranges to axlsx worksheet' do
      range = worksheet.ranges.first.last
      range.options.each_with_index do |option, i|
        expect(spreadsheet.sheet(0).cell(1, i + 1)).to eq(option)
      end
      expect(spreadsheet.sheet(0).last_row).to eq(worksheet.ranges.count)
    end

    it 'set absolute references in ranges' do
      range = range_list.ranges.values.first
      expect(range.absolute_reference).to eq("Ranges!#{range.fixed_reference}")
      expect(range_list.all? { |_k, rng| rng.absolute_reference.present? }).to be_truthy
    end
  end

  after(:each) do
    File.delete(test_file) if File.exist?(test_file)
  end

  after(:all) do
    SampleManifestExcel.reset!
  end
end
