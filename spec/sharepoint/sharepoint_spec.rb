# frozen_string_literal: true

require 'connectors/sharepoint/sharepoint'

RSpec.describe Sharepoint::HttpCallWrapper do
  let(:backend) do
    config = {}
    described_class.new(config: config)
  end

  it 'can get documents' do
    backend.get_document_batch
  end
end
