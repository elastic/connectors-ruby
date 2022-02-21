# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'
require 'connectors/sharepoint/sharepoint'
require 'connectors/sharepoint/base'

# TODO: do proper mocking
class Config
  attr_reader :cursors

  def initialize
    @cursors = {}
  end

  def index_all_drives?
    true
  end
end

RSpec.describe Sharepoint::HttpCallWrapper do
  let(:content_source) do
    Base::ContentSource.new
  end

  let(:backend) do
    described_class.new(content_source, Config.new)
  end

  it 'can get documents' do
    stub_request(:get, 'https://graph.microsoft.com/v1.0/sites/?$select=id&search=&top=10')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip,deflate',
          'Authorization' => 'Bearer BLA BLA ACCESS TOKEN',
          'Content-Type' => 'application/json',
          'Date' => 'Mon, 21 Feb 2022 16:44:02 GMT',
          'User-Agent' => 'Faraday v1.10.0'
        }
      )
      .to_return(status: 200, body: '', headers: {})
    backend.get_document_batch
  end
end
