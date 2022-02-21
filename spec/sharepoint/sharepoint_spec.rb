# frozen_string_literal: true

require 'connectors/sharepoint/sharepoint'

RSpec.describe Sharepoint::HttpCallWrapper do
  let(:backend) do
    described_class.new
  end

  it 'can get documents' do
    backend.get_document_batch
  end
end
