# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'
require 'connectors/sharepoint/sharepoint'
require 'connectors/sharepoint/base'
require 'json'
require 'time'

# TODO: do proper mocking
RSpec.describe Sharepoint::HttpCallWrapper do
  # XXX This is also stubs in lib/stubs/app_config.rb

  let(:backend) do
    described_class.new({'access_token' => 'something'})
  end

  def mock_endpoint(path, data)
    data = JSON.generate(data)

    stub_request(:get, "https://graph.microsoft.com/v1.0/#{path}")
      .with { true }
      .to_return(status: 200, body: data)
  end

  it 'can get documents' do
    # fake data
    sites = { value: [{ id: 4567 }] }
    groups = { value: [{ id: 1234, createdDateTime: Time.now }] }
    drives = { value: [{ id: 4567, driveType: 'documentLibrary' }] }
    drive = { id: 1111, driveType: 'documentLibrary' }
    children = { value: [{ folder: 'folder', id: 1111,
                           name: 'item' }] }
    permissions = {
      value: [
        { id: 666 }
      ]
    }

    mock_endpoint('sites/?$select=id&search=&top=10', sites)
    mock_endpoint('groups/?$select=id,createdDateTime', groups)
    mock_endpoint('groups/1234/sites/root?$select=id', sites)
    mock_endpoint('sites/4567/drives/?$select=id,owner,name,driveType', drives)
    # ??
    mock_endpoint('sites//drives/?$select=id,owner,name,driveType', drives)
    mock_endpoint('drives/4567/root?$select=id', drive)
    mock_endpoint('drives/4567/items/1111/children', children)
    mock_endpoint('drives/4567/items/1111/permissions', permissions)

    expect(backend.get_document_batch.size).to eq 101
  end
end
