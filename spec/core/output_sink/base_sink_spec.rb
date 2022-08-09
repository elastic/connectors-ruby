require 'core/output_sink'

def get_class_specific_public_methods(klass)
  (klass.public_methods - Object.public_methods).sort
end

describe Core::OutputSink::BaseSink do
  subject { described_class.new }
  let(:specific_sink_classes) do
    [
      Core::OutputSink::ConsoleSink,
      Core::OutputSink::CombinedSink,
      Core::OutputSink::EsSink
    ]
  end

  let(:base_sink_methods) { get_class_specific_public_methods(subject) }

  it 'base_sink methods raise an error when called' do
    expect { subject.ingest(nil) }.to raise_error('not implemented')
    expect { subject.ingest_multiple(nil) }.to raise_error('not implemented')
    expect { subject.delete(nil) }.to raise_error('not implemented')
    expect { subject.delete_multiple(nil) }.to raise_error('not implemented')
    expect { subject.flush(_size: nil) }.to raise_error('not implemented')
  end

  shared_examples 'implements all sink methods' do
    it '' do
      specific_class_public_methods = get_class_specific_public_methods(sink)

      expect(specific_class_public_methods).to eq(base_sink_methods)
    end
  end

  context 'Core::OutputSink::CombinedSink' do
    let(:sink) { Core::OutputSink::CombinedSink.new }

    it_behaves_like 'implements all sink methods'
  end

  context 'Core::OutputSink::ConsoleSink' do
    let(:sink) { Core::OutputSink::ConsoleSink.new }

    it_behaves_like 'implements all sink methods'
  end

  context 'Core::OutputSink::EsSink' do
    let(:sink) { Core::OutputSink::EsSink.new('something') }

    it_behaves_like 'implements all sink methods'
  end
end
