# frozen_string_literal: true

require 'rails_helper'
require 'pry'

RSpec.describe SampleManifestExcel::Worksheet, type: :model, sample_manifest_excel: true do
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

  context 'type' do
    let(:options) { { workbook: workbook, ranges: SampleManifestExcel.configuration.ranges.dup, password: '1111' } }

    it 'be Plates for any plate based manifest' do
      column_list = SampleManifestExcel.configuration.columns.plate_full.dup
      worksheet = SampleManifestExcel::Worksheet::DataWorksheet.new(options.merge(columns: column_list, sample_manifest: sample_manifest))
      expect(worksheet.type).to eq('Plates')
    end

    it 'be Tubes for a tube based manifest' do
      sample_manifest = create(:tube_sample_manifest, asset_type: '1dtube')
      column_list = SampleManifestExcel.configuration.columns.tube_full.dup
      worksheet = SampleManifestExcel::Worksheet::DataWorksheet.new(options.merge(columns: column_list, sample_manifest: sample_manifest))
      expect(worksheet.type).to eq('Tubes')
    end

    it 'be Tubes for a library tube based manifest' do
      sample_manifest = create(:tube_sample_manifest, asset_type: 'library')
      column_list = SampleManifestExcel.configuration.columns.tube_library_with_tag_sequences.dup
      worksheet = SampleManifestExcel::Worksheet::DataWorksheet.new(options.merge(columns: column_list, sample_manifest: sample_manifest))
      expect(worksheet.type).to eq('Tubes')
    end

    it 'be Tubes for a multiplexed library tube' do
      sample_manifest = create(:tube_sample_manifest, asset_type: 'multiplexed_library')
      column_list = SampleManifestExcel.configuration.columns.tube_multiplexed_library_with_tag_sequences.dup
      worksheet = SampleManifestExcel::Worksheet::DataWorksheet.new(options.merge(columns: column_list, sample_manifest: sample_manifest))
      expect(worksheet.type).to eq('Tubes')
    end
  end

  context 'data worksheet' do
    let!(:worksheet) do
      SampleManifestExcel::Worksheet::DataWorksheet.new(workbook: workbook,
                                                        columns: SampleManifestExcel.configuration.columns.plate_full.dup,
                                                        sample_manifest: sample_manifest, ranges: SampleManifestExcel.configuration.ranges.dup,
                                                        password: '1111')
    end

    before(:each) do
      save_file
    end

    it 'will have a axlsx worksheet' do
      expect(worksheet.axlsx_worksheet).to be_present
    end

    it 'last row should be correct' do
      expect(worksheet.last_row).to eq(spreadsheet.sheet(0).last_row)
    end

    it 'adds title and description' do
      expect(spreadsheet.sheet(0).cell(1, 1)).to eq('DNA Collections Form')
      expect(spreadsheet.sheet(0).cell(5, 1)).to eq('Study:')
      expect(spreadsheet.sheet(0).cell(5, 2)).to eq(sample_manifest.study.abbreviation)
      expect(spreadsheet.sheet(0).cell(6, 1)).to eq('Supplier:')
      expect(spreadsheet.sheet(0).cell(6, 2)).to eq(sample_manifest.supplier.name)
      expect(spreadsheet.sheet(0).cell(7, 1)).to eq('No. Plates Sent:')
      expect(spreadsheet.sheet(0).cell(7, 2)).to eq(sample_manifest.count.to_s)
    end

    it 'adds standard headings to worksheet' do
      worksheet.columns.headings.each_with_index do |heading, i|
        expect(spreadsheet.sheet(0).cell(9, i + 1)).to eq(heading)
      end
    end

    it 'unlock cells for all columns which are unlocked' do
      worksheet.columns.values.select(&:unlocked?).each do |column|
        expect(worksheet.axlsx_worksheet[column.range.first_cell.reference].style).to eq(worksheet.styles[:unlocked].reference)
        expect(worksheet.axlsx_worksheet[column.range.last_cell.reference].style).to eq(worksheet.styles[:unlocked].reference)
      end
    end

    it 'adds all of the details' do
      expect(spreadsheet.sheet(0).last_row).to eq(sample_manifest.details_array.count + 9)
    end

    it 'adds the attributes for each details' do
      [sample_manifest.details_array.first, sample_manifest.details_array.last].each do |detail|
        worksheet.columns.each do |column|
          expect(spreadsheet.sheet(0).cell(sample_manifest.details_array.index(detail) + 10, column.number)).to eq(column.attribute_value(detail))
        end
      end
    end

    it 'updates all of the columns' do
      expect(worksheet.columns.values.all?(&:updated?)).to be_truthy
    end

    it 'panes should be frozen correctly' do
      expect(worksheet.axlsx_worksheet.sheet_view.pane.x_split).to eq(worksheet.freeze_after_column(:sanger_sample_id))
      expect(worksheet.axlsx_worksheet.sheet_view.pane.y_split).to eq(worksheet.first_row - 1)
      expect(worksheet.axlsx_worksheet.sheet_view.pane.state).to eq('frozen')
    end

    it 'worksheet is protected with password but columns and rows format can be changed' do
      expect(worksheet.axlsx_worksheet.sheet_protection.password).to be_present
      expect(worksheet.axlsx_worksheet.sheet_protection.format_columns).to be_falsey
      expect(worksheet.axlsx_worksheet.sheet_protection.format_rows).to be_falsey
    end
  end

  context 'multiplexed library tube worksheet' do
    it 'must have the multiplexed library tube barcode' do
      sample_manifest = create(:tube_sample_manifest, asset_type: 'multiplexed_library', rapid_generation: true)
      sample_manifest.generate
      worksheet = SampleManifestExcel::Worksheet::DataWorksheet.new(workbook: workbook,
                                                                    columns: SampleManifestExcel.configuration.columns.tube_multiplexed_library_with_tag_sequences.dup,
                                                                    sample_manifest: sample_manifest, ranges: SampleManifestExcel.configuration.ranges.dup,
                                                                    password: '1111')
      save_file
      expect(spreadsheet.sheet(0).cell(4, 1)).to eq('Multiplexed library tube barcode:')
      mx_tubes = Tube.with_barcode(worksheet.sample_manifest.barcodes).map { |tube| tube.requests.first.target_asset }.uniq
      expect(mx_tubes.length).to eq(1)
      expect(spreadsheet.sheet(0).cell(4, 2)).to eq(mx_tubes.first.human_barcode)
    end
  end

  context 'test worksheet for library tubes' do
    let(:data) do
      {
        library_type: 'My personal library type', insert_size_from: 200, insert_size_to: 1500,
        supplier_name: 'SCG--1222_A0', volume: 1, concentration: 1, gender: 'Unknown', dna_source: 'Cell Line',
        date_of_sample_collection: 'Nov-16', date_of_sample_extraction: 'Nov-16', sample_purified: 'No',
        sample_public_name: 'SCG--1222_A0', sample_taxon_id: 9606, sample_common_name: 'Homo sapiens', phenotype: 'Unknown'
      }.with_indifferent_access
    end

    let(:attributes) do
      { workbook: workbook, columns: SampleManifestExcel.configuration.columns.tube_library_with_tag_sequences.dup,
        data: data, no_of_rows: 5, study: 'WTCCC', supplier: 'Test supplier', count: 1, type: 'Tubes' }
    end

    context 'in a valid state' do
      let!(:worksheet) { SampleManifestExcel::Worksheet::TestWorksheet.new(attributes) }

      before(:each) do
        save_file
      end

      it 'will have an axlsx worksheet' do
        expect(worksheet.axlsx_worksheet).to be_present
      end

      it 'last row should be correct' do
        expect(worksheet.last_row).to eq(worksheet.first_row + 5)
      end

      it 'adds title and description' do
        expect(spreadsheet.sheet(0).cell(1, 1)).to eq('DNA Collections Form')
        expect(spreadsheet.sheet(0).cell(5, 1)).to eq('Study:')
        expect(spreadsheet.sheet(0).cell(5, 2)).to eq(sample_manifest.study.abbreviation)
        expect(spreadsheet.sheet(0).cell(6, 1)).to eq('Supplier:')
        expect(spreadsheet.sheet(0).cell(6, 2)).to eq(sample_manifest.supplier.name)
        expect(spreadsheet.sheet(0).cell(7, 1)).to eq('No. Tubes Sent:')
        expect(spreadsheet.sheet(0).cell(7, 2)).to eq(sample_manifest.count.to_s)
      end

      it 'adds standard headings to worksheet' do
        worksheet.columns.headings.each_with_index do |heading, i|
          expect(spreadsheet.sheet(0).cell(9, i + 1)).to eq(heading)
        end
      end

      it 'adds the data' do
        data.each do |heading, value|
          worksheet.columns.find_by(:name, heading).number
          expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, heading).number)).to eq(value.to_s)
          expect(spreadsheet.sheet(0).cell(worksheet.last_row, worksheet.columns.find_by(:name, heading).number)).to eq(value.to_s)
        end
      end

      it 'creates the samples and tubes' do
        ((worksheet.first_row + 1)..worksheet.last_row).each do |i|
          sample = Sample.find_by(sanger_sample_id: spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :sanger_sample_id).number).to_i)
          expect(sample).to be_present
          expect(sample.sample_manifest).to be_present
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :sanger_tube_id).number)).to eq(sample.assets.first.human_barcode)
        end
      end

      it 'creates a library type' do
        expect(LibraryType.find_by(name: data[:library_type])).to be_present
      end
    end

    context 'in a valid state with sequence tags' do
      let!(:worksheet) { SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_library_with_tag_sequences')) }

      before(:each) do
        save_file
      end

      it 'adds some tags' do
        ((worksheet.first_row + 1)..worksheet.last_row).each do |i|
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :i7).number)).to be_present
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :i5).number)).to be_present
        end
      end
    end

    context 'in a valid state with tag groups and indexes' do
      let!(:worksheet) { SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_multiplexed_library', columns: SampleManifestExcel.configuration.columns.tube_multiplexed_library.dup)) }

      before(:each) do
        save_file
      end

      it 'adds tag group and index values' do
        ((worksheet.first_row + 1)..worksheet.last_row).each do |i|
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :tag_group).number)).to be_present
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :tag_index).number)).to be_present
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :tag2_group).number)).to be_present
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :tag2_index).number)).to be_present
        end
      end
    end

    context 'foreign barcodes' do
      it 'creates a sheet containing foreign barcodes if requested' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(cgap: true))
        save_file
        ((worksheet.first_row)..worksheet.last_row).each do |i|
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :sanger_tube_id).number)).to include('CGAP-')
        end
      end
    end

    context 'asset type' do
      it 'defaults to 1dtube' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes)
        save_file
        expect(worksheet.sample_manifest.asset_type).to eq('1dtube')
        expect(worksheet.assets.all? { |asset| asset.type == 'sample_tube' }).to be_truthy
      end

      it 'creates library tubes for library with tag sequences' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_library_with_tag_sequences'))
        save_file
        expect(worksheet.sample_manifest.asset_type).to eq('library')
        expect(worksheet.assets.all? { |asset| asset.type == 'library_tube' }).to be_truthy
      end

      it 'creates a multiplexed library tube for multiplexed_library with tag sequences' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_multiplexed_library_with_tag_sequences'))
        save_file
        expect(worksheet.sample_manifest.asset_type).to eq('multiplexed_library')
        expect(worksheet.assets.all? { |asset| asset.requests.first.target_asset == worksheet.multiplexed_library_tube }).to be_truthy
      end

      it 'creates a multiplexed library tube for multiplexed_library with tag group and index' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_multiplexed_library', columns: SampleManifestExcel.configuration.columns.tube_multiplexed_library.dup))
        save_file
        expect(worksheet.sample_manifest.asset_type).to eq('multiplexed_library')
        expect(worksheet.assets.all? { |asset| asset.requests.first.target_asset == worksheet.multiplexed_library_tube }).to be_truthy
      end
    end

    context 'in an invalid state' do
      it 'without a library type' do
        SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(validation_errors: [:library_type]))
        save_file
        expect(LibraryType.find_by(name: data[:library_type])).to be_nil
      end

      it 'with duplicate tag sequences' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_multiplexed_library_with_tag_sequences', columns: SampleManifestExcel.configuration.columns.tube_multiplexed_library_with_tag_sequences.dup, validation_errors: [:tags]))
        save_file
        expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, :i7).number)).to eq(spreadsheet.sheet(0).cell(worksheet.last_row, worksheet.columns.find_by(:name, :i7).number))
        expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, :i5).number)).to eq(spreadsheet.sheet(0).cell(worksheet.last_row, worksheet.columns.find_by(:name, :i5).number))
      end

      it 'with duplicate tag groups and indexes' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(manifest_type: 'tube_multiplexed_library', columns: SampleManifestExcel.configuration.columns.tube_multiplexed_library.dup, validation_errors: [:tags]))
        save_file
        expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, :tag_group).number)).to eq(spreadsheet.sheet(0).cell(worksheet.last_row, worksheet.columns.find_by(:name, :tag_group).number))
        expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, :tag_index).number)).to eq(spreadsheet.sheet(0).cell(worksheet.last_row, worksheet.columns.find_by(:name, :tag_index).number))
      end

      it 'without insert size from' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(validation_errors: [:insert_size_from]))
        save_file
        expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, :insert_size_from).number)).to be_nil
      end

      it 'without a sample manifest' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(validation_errors: [:sample_manifest]))
        save_file
        sample = Sample.find_by(sanger_sample_id: spreadsheet.sheet(0).cell(worksheet.first_row + 1, worksheet.columns.find_by(:name, :sanger_sample_id).number).to_i)
        expect(sample.sample_manifest).to be_nil
      end
    end
  end

  context 'test worksheet for plates' do
    let(:data) do
      {
        supplier_name: 'SCG--1222_A0', volume: 1, concentration: 1, gender: 'Unknown', dna_source: 'Cell Line',
        date_of_sample_collection: 'Nov-16', date_of_sample_extraction: 'Nov-16', sample_purified: 'No',
        sample_public_name: 'SCG--1222_A0', sample_taxon_id: 9606, sample_common_name: 'Homo sapiens', phenotype: 'Unknown'
      }.with_indifferent_access
    end

    let(:attributes) do
      { workbook: workbook, columns: SampleManifestExcel.configuration.columns.plate_default.dup,
        data: data, no_of_rows: 5, study: 'WTCCC', supplier: 'Test supplier', count: 1, type: 'Plates',
        num_plates: 2, num_samples_per_plate: 3, manifest_type: 'plate_default' }
    end

    context 'in a valid state' do
      let!(:worksheet) { SampleManifestExcel::Worksheet::TestWorksheet.new(attributes) }

      before(:each) do
        save_file
      end

      it 'will have an axlsx worksheet' do
        expect(worksheet.axlsx_worksheet).to be_present
      end

      it 'last row should be correct' do
        expect(worksheet.last_row).to eq(worksheet.first_row + (attributes[:num_plates] * attributes[:num_samples_per_plate]) - 1)
      end

      it 'adds title and description' do
        expect(spreadsheet.sheet(0).cell(1, 1)).to eq('DNA Collections Form')
        expect(spreadsheet.sheet(0).cell(5, 1)).to eq('Study:')
        expect(spreadsheet.sheet(0).cell(5, 2)).to eq(sample_manifest.study.abbreviation)
        expect(spreadsheet.sheet(0).cell(6, 1)).to eq('Supplier:')
        expect(spreadsheet.sheet(0).cell(6, 2)).to eq(sample_manifest.supplier.name)
        expect(spreadsheet.sheet(0).cell(7, 1)).to eq('No. Plates Sent:')
        expect(spreadsheet.sheet(0).cell(7, 2)).to eq(sample_manifest.count.to_s)
      end

      it 'adds standard headings to worksheet' do
        worksheet.columns.headings.each_with_index do |heading, i|
          expect(spreadsheet.sheet(0).cell(9, i + 1)).to eq(heading)
        end
      end

      it 'adds the data' do
        data.each do |heading, value|
          worksheet.columns.find_by(:name, heading).number
          expect(spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, heading).number)).to eq(value.to_s)
          expect(spreadsheet.sheet(0).cell(worksheet.last_row, worksheet.columns.find_by(:name, heading).number)).to eq(value.to_s)
        end
      end

      it 'creates the samples, plates and wells' do
        ((worksheet.first_row)..worksheet.last_row).each do |i|
          sample = Sample.find_by(sanger_sample_id: spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :sanger_sample_id).number))
          expect(sample).to be_present
          expect(sample.sample_manifest).to be_present
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :sanger_plate_id).number)).to eq(sample.assets.first.plate.human_barcode)
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :well).number)).to eq(sample.assets.first.map_description)
        end
      end
    end

    context 'foreign barcodes' do
      it 'creates a sheet containing foreign barcodes if requested' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(cgap: true))
        save_file
        ((worksheet.first_row)..worksheet.last_row).each do |i|
          expect(spreadsheet.sheet(0).cell(i, worksheet.columns.find_by(:name, :sanger_plate_id).number)).to include('CGAP-')
        end
      end
    end

    context 'manifest type' do
      it 'creates plates for plate' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes)
        save_file
        expect(worksheet.sample_manifest.asset_type).to eq('plate')
        expect(worksheet.assets.all? { |asset| asset.type == 'plate' }).to be_truthy
      end
    end

    context 'in an invalid state' do
      it 'without a sample manifest' do
        worksheet = SampleManifestExcel::Worksheet::TestWorksheet.new(attributes.merge(validation_errors: [:sample_manifest]))
        save_file
        sample = Sample.find_by(sanger_sample_id: spreadsheet.sheet(0).cell(worksheet.first_row, worksheet.columns.find_by(:name, :sanger_sample_id).number))
        expect(sample.sample_manifest).to be_nil
      end
    end
  end

  after(:each) do
    File.delete(test_file) if File.exist?(test_file)
  end

  after(:all) do
    SampleManifestExcel.reset!
  end
end
