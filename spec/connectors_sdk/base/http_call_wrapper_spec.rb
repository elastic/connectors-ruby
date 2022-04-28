#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/share_point/http_call_wrapper'
require 'connectors_sdk/base/http_call_wrapper'
require 'connectors_sdk/office365/custom_client'
require 'connectors_sdk/share_point/extractor'

describe ConnectorsSdk::Base::HttpCallWrapper do
  let(:wrapper_class) { ConnectorsSdk::SharePoint::HttpCallWrapper }
  let(:extractor_class) { ConnectorsSdk::SharePoint::Extractor }
  let(:custom_client_error) { ConnectorsSdk::Office365::CustomClient::ClientError }
  let(:backend) do
    wrapper_class.new
  end

  let(:params) do
    {
      :cursors => {},
      :access_token => 'something',
      :index_permissions => true
    }
  end

  context '.document_batch' do
    it 'can get documents' do
      allow_any_instance_of(extractor_class).to receive(:yield_document_changes)
        .and_yield(:create_or_update, 1, nil)
        .and_yield(:create_or_update, 2, nil)
        .and_yield(:create_or_update, 3, nil)
        .and_yield(:create_or_update, 4, nil)
        .and_yield(:create_or_update, 5, nil)
      results, _cursors, _completed = backend.document_batch(params)

      expect(results.size).to eq 5
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
      allow(extractor_class).to receive(:new).and_return(extractor_mock)
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
      allow(extractor_class).to receive(:new).and_return(extractor_mock)
    end

    context 'with valid access token' do
      it 'returns deleted ids' do
        allow(extractor_mock).to receive(:yield_deleted_ids).with(ids).and_yield(ids.first).and_yield(ids.second)
        expect(backend.deleted(params)).to eq ids[0, 2]
      end
    end

    context 'with invalid access token' do
      it 'raise InvalidTokenError' do
        allow(extractor_mock).to receive(:yield_deleted_ids).with(ids).and_raise(custom_client_error.new(401, nil))
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
      allow(extractor_class).to receive(:new).and_return(extractor_mock)
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
        allow(extractor_mock).to receive(:yield_permissions).with(user_id).and_raise(custom_client_error.new(401, nil))
        expect { backend.permissions(params) }.to raise_error(ConnectorsShared::InvalidTokenError)
      end
    end
  end

  context '.source_status' do
    let(:params) { { :access_token => 'access_token' } }

    context 'remote source is up' do
      it 'returns OK status' do
        allow(backend).to receive(:health_check).and_return({})
        response = backend.source_status(params)
        expect(response[:status]).to eq 'OK'
      end
    end

    context 'remote source is down' do
      it 'returns FAILURE status' do
        allow(backend).to receive(:health_check).and_raise(StandardError)
        response = backend.source_status(params)
        expect(response[:status]).to eq 'FAILURE'
      end
    end
  end
end
