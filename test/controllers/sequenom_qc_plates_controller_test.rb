require 'test_helper'
require 'sdb/sample_manifests_controller'

class SequenomQcPlatesControllerTest < ActionController::TestCase
  context '#create' do
    setup do
      @controller = SequenomQcPlatesController.new
      @request    = ActionController::TestRequest.create(@controller)
      @user       = create :manager, barcode: 'ID99A', swipecard_code: '1234567'
      @controller.stubs(:current_user).returns(@user)
    end

    should 'send print request' do
      barcode = mock('barcode')
      barcode.stubs(:barcode).returns(23)
      PlateBarcode.stubs(:create).returns(barcode)

      barcode_printer = create :barcode_printer
      LabelPrinter::PmbClient.expects(:get_label_template_by_name).returns('data' => [{ 'id' => 15 }])

      plate1 = create :plate, barcode: '9168137'
      plate2 = create :plate, barcode: '163993'

      RestClient.expects(:post)

      post :create, params: { 'user_barcode' => '1234567',
                              'input_plate_names' => { '1' => plate1.ean13_barcode.to_s, '2' => plate2.ean13_barcode.to_s, '3' => '', '4' => '' },
                              'plate_prefix' => 'QC',
                              'gender_check_bypass' => '1',
                              'barcode_printer' => { 'id' => barcode_printer.id.to_s },
                              'number_of_barcodes' => '1' }
    end
  end
end
