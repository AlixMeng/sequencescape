module LabelPrinter
  module Label
    class SampleManifestRedirect
      attr_reader :options, :sample_manifest

      def initialize(options)
        @sample_manifest = options[:sample_manifest]
        @printer_type_class = options[:printer_type_class]
        @options = options
      end

      def to_h
        case sample_manifest.asset_type
        when 'plate'
          if @printer_type_class.double_label?
            SampleManifestPlateDouble.new(options).to_h
          else
            SampleManifestPlate.new(options).to_h
          end
        when '1dtube'
          SampleManifestTube.new(options).to_h
        when 'library'
          SampleManifestTube.new(options).to_h
        when 'multiplexed_library'
          SampleManifestMultiplex.new(options).to_h
        end
      end
    end
  end
end
