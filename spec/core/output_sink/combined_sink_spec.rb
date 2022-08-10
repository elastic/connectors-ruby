require 'core/output_sink/base_sink'
require 'core/output_sink/combined_sink'

require 'spec_helper'

describe Core::OutputSink::CombinedSink do
  let(:first_sink) { double }
  let(:second_sink) { double }
  subject { described_class.new([first_sink, second_sink]) }

  it_behaves_like 'implements all methods of base class' do
    let(:concrete_class_instance) { subject }
    let(:base_class_instance) { Core::OutputSink::BaseSink.new }
  end

  context '.ingest' do
    let(:doc) { { :id => 1, :something => :else } }

    it 'calls ingest for each sink' do
      expect(first_sink).to receive(:ingest).with(doc)
      expect(second_sink).to receive(:ingest).with(doc)

      subject.ingest(doc)
    end
  end

  context '.ingest_multiple' do
    let(:docs) { [{ :id => 1, :something => :else }, { :id => 2, :another => :one }] }

    it 'calls ingest_multiple for each sink' do
      expect(first_sink).to receive(:ingest_multiple).with(docs)
      expect(second_sink).to receive(:ingest_multiple).with(docs)

      subject.ingest_multiple(docs)
    end
  end

  context '.delete' do
    let(:id) { 15 }

    it 'calls delete for each sink' do
      expect(first_sink).to receive(:delete).with(id)
      expect(second_sink).to receive(:delete).with(id)

      subject.delete(id)
    end
  end

  context '.delete_multiple' do
    let(:ids) { [1, 2, 3, 15, 11, 17] }

    it 'calls delete_multiple for each sink' do
      expect(first_sink).to receive(:delete_multiple).with(ids)
      expect(second_sink).to receive(:delete_multiple).with(ids)

      subject.delete_multiple(ids)
    end
  end

  context '.flush' do
    let(:size) { 99 }

    it 'calls flush for each sink' do
      expect(first_sink).to receive(:flush).with(:size => size)
      expect(second_sink).to receive(:flush).with(:size => size)

      subject.flush(size: size)
    end
  end
end
