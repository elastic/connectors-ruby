#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'active_support/core_ext/object/deep_dup'
require 'connectors_sdk/share_point/http_call_wrapper'
require 'connectors_sdk/base/custom_client'
require 'connectors_sdk/base/adapter'
require 'connectors_sdk/base/config'
require 'connectors_sdk/base/extractor'
require 'json'
require 'time'

# TODO: do proper mocking
RSpec.describe ConnectorsSdk::SharePoint::HttpCallWrapper do
  # XXX This is also stubs in lib/stubs/app_config.rb

  let(:backend) do
    described_class.new
  end

  let(:params) do
    { 'access_token' => 'something' }
  end

  def mock_endpoint(path, data)
    data = JSON.generate(data)

    stub_request(:get, "https://graph.microsoft.com/v1.0/#{path}")
      .with { true }
      .to_return(status: 200, body: data)
  end

  context '.document_batch' do
    it 'can get documents' do
      # fake data
      sites = { value: [{ id: 4567 }] }
      groups = { value: [{ id: 1234, createdDateTime: Time.now }] }
      drives = { value: [{ id: 4567, driveType: 'documentLibrary' }] }
      drive = { id: 1111, driveType: 'documentLibrary' }
      children = { value: [{ folder: 'folder', id: 1111, name: 'item' }] }
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

      expect(backend.document_batch(params).size).to eq 101
    end
  end

  context '.download' do
    let(:extractor_mock) { double }
    let(:download_params) { { :memento => 'mori' } }

    before(:each) do
      allow(ConnectorsSdk::SharePoint::Extractor).to receive(:new).and_return(extractor_mock)
    end

    it 'calls extractor.download method with same params' do
      expect(extractor_mock).to receive(:download).with(download_params)
      backend.download(params, download_params)
    end

    context 'when extractor raises an error' do
      let(:error_class) { TimeoutError }

      before(:each) do
        allow(extractor_mock).to receive(:download).and_raise(error_class)
      end

      it 'does not suppress errors from extractor' do
        expect { backend.download(params, download_params) }.to raise_error(error_class)
      end
    end
  end
end
