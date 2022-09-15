# frozen_string_literal: true

require 'connectors/example/connector'
require 'spec_helper'

describe Connectors::Example::Connector do
  subject { described_class.new(local_configuration: local_configuration, remote_configuration: remote_configuration) }
  let(:local_configuration) { {} }
  let(:remote_configuration) do
    {
       :foo => {
         :label => 'Foo',
         :value => 'something'
       }
    }
  end

  it_behaves_like 'a connector'

  context '#is_healthy?' do
    it 'returns ok' do
      expect(subject.is_healthy?).to eq(true)
    end
  end

  context '#yield_documents' do
    before do
      @documents = []

      subject.yield_documents { |doc| @documents << doc }
    end

    it 'returns some documents' do
      expect(@documents.size).to be > 0
    end

    it 'returns attachments' do
      expect(@documents.all? { |doc| doc.has_key?(:_attachment) }).to be true
    end
  end
end
