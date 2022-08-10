require 'core/output_sink'

describe Core::OutputSink::BaseSink do
  subject { described_class.new }

  it 'base_sink methods raise an error when called' do
    expect { subject.ingest(nil) }.to raise_error('not implemented')
    expect { subject.ingest_multiple(nil) }.to raise_error('not implemented')
    expect { subject.delete(nil) }.to raise_error('not implemented')
    expect { subject.delete_multiple(nil) }.to raise_error('not implemented')
    expect { subject.flush(_size: nil) }.to raise_error('not implemented')
  end
end
