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

  context '#source_status' do
    it 'returns ok' do
      expect(subject.source_status({})).to include(:status => 'OK')
    end
  end

  context '#yield_documents' do
    it 'returns some documents' do
      documents = []

      subject.yield_documents { |doc| documents << doc }

      expect(documents.size).to be > 0
    end
  end
end
