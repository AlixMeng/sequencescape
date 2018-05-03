# frozen_string_literal: true

require 'rails_helper'

describe Barcode, type: :model do
  shared_examples 'a basic barcode' do
    describe '#human_barcode' do
      subject { barcode.human_barcode }
      it { is_expected.to eq human_barcode }
    end
    describe '#machine_barcode' do
      subject { barcode.machine_barcode }
      it { is_expected.to eq machine_barcode }
    end

    describe '#summary' do
      subject { barcode.summary }
      it { is_expected.to be_a Hash }
      it { is_expected.to eq summary }
    end
  end

  shared_examples 'a composable barcode' do
    describe '#barcode_number' do
      subject { barcode.number }
      it { is_expected.to eq number }
    end
    describe '#barcode_prefix' do
      subject { barcode.barcode_prefix }
      it { is_expected.to eq barcode_prefix }
    end
  end

  shared_examples 'an ean13 barcode' do
    describe '#ean13_barcode?' do
      subject { barcode.ean13_barcode? }
      it { is_expected.to be true }
    end
    describe '#ean13_barcode' do
      subject { barcode.ean13_barcode }
      it { is_expected.to eq ean13_barcode }
    end
  end

  shared_examples 'a code128 barcode' do
    describe '#code128_barcode?' do
      subject { barcode.code128_barcode? }
      it { is_expected.to be true }
    end
    describe '#code128_barcode' do
      subject { barcode.code128_barcode }
      it { is_expected.to eq code128_barcode }
    end
  end

  shared_examples 'not an ean13 barcode' do
    describe '#ean13_barcode?' do
      subject { barcode.ean13_barcode? }
      it { is_expected.to be false }
    end
    describe '#ean13_barcode' do
      subject { barcode.ean13_barcode }
      it { is_expected.to be_nil }
    end
  end

  context 'sanger_ean13' do
    let(:barcode) { build :sanger_ean13, barcode: barcode_value, format: barcode_format }

    let(:barcode_value) { 'DN12345U' }
    let(:number) { 12345 }
    let(:barcode_prefix) { 'DN' }
    let(:suffix) { 'U' }
    let(:barcode_format) { 'sanger_ean13' }
    let(:human_barcode) { 'DN12345U' }
    let(:machine_barcode) { '1220012345855' }
    let(:ean13_barcode) { '1220012345855' }
    let(:code128_barcode) { '1220012345855' }
    let(:summary) do
      {
        number: '12345',
        prefix: 'DN',
        ean13: '1220012345855',
        machine_barcode: '1220012345855'
      }
    end
    it_behaves_like 'a basic barcode'
    it_behaves_like 'a composable barcode'
    it_behaves_like 'an ean13 barcode'
    it_behaves_like 'a code128 barcode'

    it 'is valid' do
      expect(barcode).to be_valid
    end

    context 'with an incompatible format' do
      let(:barcode_value) { 'notabarcode' }
      it 'is not valid' do
        expect(barcode).not_to be_valid
      end
    end
  end

  context 'infinium' do
    let(:barcode) { build :infinium, barcode: barcode_value, format: barcode_format }

    let(:barcode_value) { 'WG0010602-DNA' }
    let(:barcode_format) { 'infinium' }
    let(:number) { 10602 }
    let(:barcode_prefix) { 'WG' }
    let(:suffix) { 'DNA' }
    let(:human_barcode) { 'WG0010602-DNA' }
    let(:machine_barcode) { 'WG0010602-DNA' }
    let(:code128_barcode) { 'WG0010602-DNA' }
    let(:summary) do
      {
        number: '10602',
        prefix: 'WG',
        machine_barcode: 'WG0010602-DNA'
      }
    end
    it_behaves_like 'a basic barcode'
    it_behaves_like 'a composable barcode'
    it_behaves_like 'not an ean13 barcode'
    it_behaves_like 'a code128 barcode'

    context 'with an incompatible format' do
      let(:barcode_value) { 'notabarcode' }
      it 'is not valid' do
        expect(barcode).not_to be_valid
      end
    end
  end

  context 'fluidigm' do
    let(:barcode) { build :fluidigm, barcode: barcode_value, format: barcode_format }

    let(:barcode_value) { '1662051218' }
    let(:barcode_format) { 'fluidigm' }
    let(:human_barcode) { '1662051218' }
    let(:machine_barcode) { '1662051218' }
    let(:code128_barcode) { '1662051218' }
    let(:prefix) { nil }

    let(:summary) do
      {
        number: '1662051218',
        prefix: nil,
        machine_barcode: '1662051218'
      }
    end
    it_behaves_like 'a basic barcode'
    it_behaves_like 'not an ean13 barcode'
    it_behaves_like 'a code128 barcode'

    context 'with an incompatible format' do
      let(:barcode_value) { 'notabarcode' }
      it 'is not valid' do
        expect(barcode).not_to be_valid
      end
    end
  end

  context 'external' do
    let(:barcode) { build :external, barcode: barcode_value, format: barcode_format }

    let(:barcode_value) { 'EXT_135432_D' }
    let(:barcode_format) { 'external' }
    let(:number) { 135432 }
    let(:barcode_prefix) { 'EXT_' }
    let(:suffix) { '_D' }
    let(:human_barcode) { 'EXT_135432_D' }
    let(:machine_barcode) { 'EXT_135432_D' }
    let(:code128_barcode) { 'EXT_135432_D' }
    let(:prefix) { nil }

    let(:summary) do
      {
        number: '135432',
        prefix: 'EXT_',
        machine_barcode: 'EXT_135432_D'
      }
    end
    it_behaves_like 'a basic barcode'
    it_behaves_like 'not an ean13 barcode'
    it_behaves_like 'a composable barcode'
    it_behaves_like 'a code128 barcode'
  end

  context 'external - odd format' do
    let(:barcode) { build :external, barcode: barcode_value, format: barcode_format }

    let(:barcode_value) { 'Q123RT12E45' }
    let(:barcode_format) { 'external' }
    let(:number) { nil }
    let(:barcode_prefix) { nil }
    let(:suffix) { nil }
    let(:human_barcode) { 'Q123RT12E45' }
    let(:machine_barcode) { 'Q123RT12E45' }
    let(:code128_barcode) { 'Q123RT12E45' }
    let(:prefix) { nil }

    let(:summary) do
      {
        number: '',
        prefix: nil,
        machine_barcode: 'Q123RT12E45'
      }
    end
    it_behaves_like 'a basic barcode'
    it_behaves_like 'not an ean13 barcode'
    it_behaves_like 'a composable barcode'
    it_behaves_like 'a code128 barcode'
  end

  context 'foreign - CGAP format' do
    let(:barcode) { build :cgap, barcode: barcode_value, format: barcode_format }

    let(:barcode_value) { 'CGAP-ABC123' }
    let(:barcode_format) { 'cgap' }
    let(:number) { 'ABC12' }
    let(:barcode_prefix) { 'CGAP-' }
    let(:suffix) { '3' }
    let(:human_barcode) { 'CGAP-ABC123' }
    let(:machine_barcode) { 'CGAP-ABC123' }
    let(:code128_barcode) { 'CGAP-ABC123' }
    let(:prefix) { nil }

    let(:summary) do
      {
        number: 'ABC12',
        prefix: 'CGAP-',
        machine_barcode: 'CGAP-ABC123'
      }
    end
    it_behaves_like 'a basic barcode'
    it_behaves_like 'not an ean13 barcode'
    it_behaves_like 'a composable barcode'
    it_behaves_like 'a code128 barcode'
  end
end
