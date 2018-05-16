# frozen_string_literal: true

module SampleManifestExcel
  module Worksheet
    ##
    # A test worksheet is necessary for testing uploads.
    class TestWorksheet < Base
      include Helpers::Worksheet

      attr_accessor :data, :no_of_rows, :study, :supplier, :count, :type, :validation_errors, :missing_columns, :partial, :cgap, :num_plates, :num_samples_per_plate
      attr_reader :dynamic_attributes, :tags
      attr_writer :manifest_type

      def initialize(attributes = {})
        super
        @validation_errors ||= []
        if type == 'Plates'
          # create a worksheet for Plates
          create_plate_dynamic_attributes
        else
          # by default create a worksheet for Tubes
          create_library_type
          create_reference_genome
          create_tube_dynamic_attributes
          create_tube_requests
        end
        create_styles
        add_title_and_description(study, supplier, count)
        add_headers
        add_data
      end

      def last_row
        @last_row ||= compute_last_row
      end

      def compute_last_row
        if %w[plate].include? manifest_type
          first_row + (num_plates * num_samples_per_plate) - 1
        else
          first_row + no_of_rows
        end
      end

      def assets
        @assets ||= []
      end

      def empty_columns
        %w[supplier_name tag_oligo tag2_oligo]
      end

      def manifest_type
        @manifest_type ||= '1dtube'
      end

      def sample_manifest
        @sample_manifest ||= create_sample_manifest
      end

      def create_sample_manifest
        if %w[plate].include? manifest_type
          FactoryGirl.create(:sample_manifest_with_samples_for_plates, num_plates: num_plates, num_samples_per_plate: num_samples_per_plate, rapid_generation: true)
        else
          FactoryGirl.create(:sample_manifest, asset_type: manifest_type, rapid_generation: true)
        end
      end

      def multiplexed_library_tube
        @multiplexed_library_tube ||= FactoryGirl.create(:multiplexed_library_tube)
      end

      private

      def initialize_dynamic_attributes
        {}.tap do |hsh|
          first_to_last.each do |i|
            hsh[i] = {}
          end
        end.with_indifferent_access
      end

      def create_plate_dynamic_attributes
        @dynamic_attributes = initialize_dynamic_attributes
        setup_sample_dynamic_attributes
      end

      def setup_sample_dynamic_attributes
        sm_samples = sample_manifest.samples
        sample_index = 0
        first_to_last.each do |sheet_row|
          cur_sample = sm_samples[sample_index]
          if validation_errors.include?(:sample_manifest)
            cur_sample.sample_manifest = nil
            cur_sample.save
          end
          # set the sample id
          dynamic_attributes[sheet_row][:sanger_sample_id] = cur_sample.sanger_sample_id

          # set the plate barcode
          dynamic_attributes[sheet_row][:sanger_plate_id] = if cgap
                                                              if validation_errors.include?(:sample_plate_id_duplicates)
                                                                'CGAP-99999'
                                                              elsif validation_errors.include?(:sample_plate_id_unrecognised_foreign)
                                                                "INVALID-#{cur_sample.assets.first.plate.id.to_s.upcase}#{(cur_sample.assets.first.plate.id % 10).to_s.upcase}"
                                                              else
                                                                "CGAP-#{cur_sample.assets.first.plate.id.to_s(16).upcase}#{(cur_sample.assets.first.plate.id % 16).to_s(16).upcase}"
                                                              end
                                                            else
                                                              cur_sample.assets.first.plate.human_barcode
                                                            end
          # set the well position
          dynamic_attributes[sheet_row][:well] = cur_sample.assets.first.map_description

          sample_index += 1
        end
      end

      def create_tube_dynamic_attributes
        @dynamic_attributes = initialize_dynamic_attributes
        create_tube_samples
        create_tags
      end

      def create_tube_samples
        first_to_last.each do |sheet_row|
          create_tube_asset do |asset|
            sample = asset.samples.first
            unless validation_errors.include?(:sample_manifest)
              sample.sample_manifest = sample_manifest
              sample.save
            end
            dynamic_attributes[sheet_row][:sanger_sample_id] = sample.sanger_sample_id
            dynamic_attributes[sheet_row][:sanger_tube_id] = if cgap
                                                               tube_row_num = (sheet_row - first_row) + 1
                                                               if validation_errors.include?(:sample_tube_id_duplicates) && tube_row_num < 3
                                                                 'CGAP-99999'
                                                               else
                                                                 "CGAP-#{tube_row_num.to_s(16).upcase}#{(tube_row_num % 16).to_s(16).upcase}"
                                                               end
                                                             else
                                                               asset.human_barcode
                                                             end
          end
        end
      end

      # Adds title and description (study abbreviation, supplier name, number of assets sent)
      # to a worksheet.
      def add_title_and_description(study, supplier, count)
        add_row ['DNA Collections Form']
        add_rows(3)
        add_row ['Study:', study]
        add_row ['Supplier:', supplier]
        add_row ["No. #{type} Sent:", count]
        add_rows(1)
      end

      def first_to_last
        first_row..last_row
      end

      def empty_row?(row_num)
        (row_num == last_row) || (row_num == (last_row - 1))
      end

      def add_data
        first_to_last.each do |n|
          axlsx_worksheet.add_row do |row|
            columns.each do |column|
              row.add_cell add_cell_data(column, n, partial), type: column.type, style: styles[:unlocked].reference
            end
          end
        end
      end

      def add_cell_data(column, row_num, partial)
        if partial && empty_row?(row_num)
          (data[column.name] || dynamic_attributes[row_num][column.name]) unless empty_columns.include?(column.name)
        elsif validation_errors.include?(:insert_size_from) && column.name == 'insert_size_from' && row_num == first_row
          nil
        else
          data[column.name] || dynamic_attributes[row_num][column.name]
        end
      end

      def create_tube_asset
        asset = if %w[multiplexed_library library].include? manifest_type
                  FactoryGirl.create(:library_tube_with_barcode)
                else
                  FactoryGirl.create(:sample_tube_with_sanger_sample_id)
                end
        assets << asset
        yield(asset) if block_given?
      end

      def create_tube_requests
        assets.each do |asset|
          FactoryGirl.create(:external_multiplexed_library_tube_creation_request, asset: asset, target_asset: multiplexed_library_tube) if manifest_type == 'multiplexed_library'
        end
      end

      def create_library_type
        return if validation_errors.include?(:library_type)
        LibraryType.where(name: data[:library_type]).first_or_create
      end

      def create_reference_genome
        return if validation_errors.include?(:reference_genome)
        ReferenceGenome.where(name: data[:reference_genome]).first_or_create
      end

      def create_tags
        oligos = Tags::ExampleData.new.take(first_row, last_row, validation_errors.include?(:tags))
        dynamic_attributes.each do |k, _v|
          dynamic_attributes[k].merge!(oligos[k])
        end
      end
    end
  end
end
