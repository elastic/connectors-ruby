require 'core/output_sink/console_sink'

require 'spec_helper'

describe Core::OutputSink::ConsoleSink do
  subject { described_class.new }

  it_behaves_like 'implements all methods of base class' do
    let(:concrete_class_instance) { subject }
    let(:base_class_instance) { Core::OutputSink::BaseSink.new }
  end

  context '.ingest' do
    let(:doc) { { :id => 1, :something => :else } }

    it 'outputs a doc into stdout' do
      expect { subject.ingest(doc) }.to output(/#{doc}/).to_stdout
    end
  end

  context '.ingest_multiple' do
    let(:docs) { [{ :id => 1, :something => :else }, { :id => 2, :another => :one }] }

    it 'outputs docs into stdout' do
      expect { subject.ingest_multiple(docs) }.to output(/#{docs}/).to_stdout
    end
  end

  context '.delete' do
    let(:id) { 15 }

    it 'outputs deleted id into stdout' do
      expect { subject.delete(id) }.to output(/#{id}/).to_stdout
    end
  end

  context '.delete_multiple' do
    let(:ids) { [1, 2, 3, 15, 11, 17] }

    it 'outputs deleted ids into stdout' do
      expect { subject.delete_multiple(ids) }.to output(/#{ids}/).to_stdout
    end
  end

  context '.flush' do
    let(:size) { 99 }

    it 'outputs flush size into stdout' do
      expect { subject.flush(size: size) }.to output(/#{size}/).to_stdout
    end
  end
end
