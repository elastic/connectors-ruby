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
    {
      :access_token => 'something',
      :index_permissions => true
    }
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

      expect(backend.document_batch(params).size).to eq 100
      expect(backend.extractor(params).config.index_permissions).to be_truthy
    end
  end

  context '.download' do
    let(:extractor_mock) { double }
    let(:download_params) { { :memento => 'mori' } }
    let(:params) do
      {
        :access_token => 'access_token',
        :meta => {
          :download_url => 'download_url'
        }
      }
    end

    before(:each) do
      allow(ConnectorsSdk::SharePoint::Extractor).to receive(:new).and_return(extractor_mock)
    end

    it 'calls extractor.download method with same params' do
      expect(extractor_mock).to receive(:download).with(:download_url => 'download_url')
      backend.download(params)
    end

    context 'when extractor raises an error' do
      let(:error_class) { TimeoutError }

      before(:each) do
        allow(extractor_mock).to receive(:download).and_raise(error_class)
      end

      it 'does not suppress errors from extractor' do
        expect { backend.download(params) }.to raise_error(error_class)
      end
    end
  end

  context '.deleted' do
    let(:extractor_mock) { double }
    let(:ids) { 10.times.collect { random_string } }
    let(:params) do
      {
          :access_token => 'access_token',
          :ids => ids
      }
    end

    before(:each) do
      allow(ConnectorsSdk::SharePoint::Extractor).to receive(:new).and_return(extractor_mock)
    end

    context 'with valid access token' do
      it 'returns deleted ids' do
        allow(extractor_mock).to receive(:yield_deleted_ids).with(ids).and_yield(ids.first).and_yield(ids.second)
        expect(backend.deleted(params)).to eq ids[0, 2]
      end
    end

    context 'with invalid access token' do
      it 'raise InvalidTokenError' do
        allow(extractor_mock).to receive(:yield_deleted_ids).with(ids).and_raise(ConnectorsSdk::Office365::CustomClient::ClientError.new(401, nil))
        expect { backend.deleted(params) }.to raise_error(ConnectorsShared::InvalidTokenError)
      end
    end
  end

  context '.permissions' do
    let(:extractor_mock) { double }
    let(:user_id) { 'user_id' }
    let(:params) do
      {
          :access_token => 'access_token',
          :user_id => user_id
      }
    end

    before(:each) do
      allow(ConnectorsSdk::SharePoint::Extractor).to receive(:new).and_return(extractor_mock)
    end

    context 'with valid access token' do
      let(:permissions) { %w[permissions1 permission2] }
      it 'returns permissions' do
        allow(extractor_mock).to receive(:yield_permissions).with(user_id).and_yield(permissions)
        expect(backend.permissions(params)).to eq permissions
      end
    end

    context 'with invalid access token' do
      it 'raise InvalidTokenError' do
        allow(extractor_mock).to receive(:yield_permissions).with(user_id).and_raise(ConnectorsSdk::Office365::CustomClient::ClientError.new(401, nil))
        expect { backend.permissions(params) }.to raise_error(ConnectorsShared::InvalidTokenError)
      end
    end
  end

  context '.source_status' do
    let(:params) { { :access_token => 'access_token' } }

    context 'remote source is up' do
      it 'returns OK status' do
        allow_any_instance_of(ConnectorsSdk::Office365::CustomClient).to receive(:me).and_return({})
        response = backend.source_status(params)
        expect(response[:status]).to eq 'OK'
      end
    end

    context 'remote source is down' do
      it 'returns FAILURE status' do
        allow_any_instance_of(ConnectorsSdk::Office365::CustomClient).to receive(:me).and_raise(StandardError)
        response = backend.source_status(params)
        expect(response[:status]).to eq 'FAILURE'
      end
    end
  end
end
