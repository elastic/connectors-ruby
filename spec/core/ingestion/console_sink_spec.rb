require 'core/ingestion/console_sink'

require 'spec_helper'

describe Core::Ingestion::ConsoleSink do
  subject { described_class.new }

  context '.ingest' do
    let(:doc) { { :id => 1, :something => :else } }

    it 'outputs a doc into stdout' do
      expect { subject.ingest(doc[:id], doc) }.to output(/#{doc}/).to_stdout
    end
  end

  context '.delete' do
    let(:id) { 15 }

    it 'outputs deleted id into stdout' do
      expect { subject.delete(id) }.to output(/#{id}/).to_stdout
    end
  end

  context '.flush' do
    it 'outputs flush fact into stdout' do
      expect { subject.flush }.to output(/Flush/).to_stdout
    end
  end
end
