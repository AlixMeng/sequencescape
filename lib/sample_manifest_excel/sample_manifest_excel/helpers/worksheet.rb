module SampleManifestExcel
  module Helpers

    ##
    # Add the basic styles which are the same across all worksheets.
    module Worksheet
      STYLES = { unlocked: { locked: false, border: { style: :thin, color: '00' } },
                 wrap_text: { alignment: { horizontal: :center, vertical: :center, wrap_text: true },
                              border: { style: :thin, color: '00', edges: [:left, :right, :top, :bottom] } }
                }

      def create_worksheet
        insert_axlsx_worksheet('DNA Collections Form')
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

      def add_headers
        add_row columns.headings, styles[:wrap_text].reference
      end

      # The row where the table with data starts (after headings)
      def first_row
        10
      end

      def styles
        @styles ||= {}
      end

      def create_styles
        styles.tap do |s|
          STYLES.each do |k, style|
            s[k] = Style.new(workbook, style)
          end
        end
      end

      class Style
        attr_reader :options, :reference

        def initialize(workbook, options)
          @options = options
          @reference = workbook.styles.add_style options
        end
      end
    end
  end
end