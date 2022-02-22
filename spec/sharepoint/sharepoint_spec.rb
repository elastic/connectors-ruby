# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'
require 'connectors/sharepoint/sharepoint'
require 'connectors/sharepoint/base'
require 'json'
require 'time'

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
    sites = JSON.generate({ value: [{ id: 4567 }] })

    stub_request(:get, 'https://graph.microsoft.com/v1.0/sites/?$select=id&search=&top=10')
      .with { true }
      .to_return(status: 200, body: sites, headers: {})

    groups = { value: [{ id: 1234, createdDateTime: Time.now }] }

    stub_request(:get, 'https://graph.microsoft.com/v1.0/groups/?$select=id,createdDateTime')
      .with { true }
      .to_return(status: 200, body: JSON.generate(groups), headers: {})

    stub_request(:get, 'https://graph.microsoft.com/v1.0/groups/1234/sites/root?$select=id')
      .with { true }
      .to_return(status: 200,
                 body: sites,
                 headers: {})

    drives = JSON.generate({ value: [{ id: 4567 }] })

    stub_request(:get, 'https://graph.microsoft.com/v1.0/sites/4567/drives/?$select=id,owner,name,driveType')
      .with { true }
      .to_return(status: 200,
                 body: drives,
                 headers: {})
    # ??
    stub_request(:get, 'https://graph.microsoft.com/v1.0/sites//drives/?$select=id,owner,name,driveType')
      .with { true }
      .to_return(status: 200,
                 body: drives,
                 headers: {})

    backend.get_document_batch
  end
end
