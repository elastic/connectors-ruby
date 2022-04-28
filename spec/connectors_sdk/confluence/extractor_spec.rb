#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/helpers/atlassian_time_formatter'
require 'fixtures/atlassian/confluence'

describe ConnectorsSdk::Confluence::Extractor do
  include ConnectorsSdk::Helpers::AtlassianTimeFormatter
  include ConnectorsSdk::Fixtures::Atlassian::Confluence

  let(:content_source_id) { BSON::ObjectId.new }
  let(:cursors) { { :space => 2 } }
  let(:base_url) { 'https://swiftypedevelopment.atlassian.net' }
  let(:api_url) { 'https://api.atlassian.com/ex/confluence/abc123' }
  let(:max_documents_to_extract_for_job) { 1_000_000 }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:access_token) { 'confluence_is_shit' }
  let(:authorization_data) { { 'access_token' => access_token, 'base_url' => base_url, 'cloud_id' => 'abc123' } }
  let(:oauth_config) { { :client_id => 'client_id', :client_secret => 'client_secret', :base_url => base_url } }
  let!(:token_request) do
    stub_request(:get, "#{api_url}/rest/api/user/current").to_return(:status => 200)
  end
  let(:service_type) { 'confluence_cloud' }
  let(:config) do
    ConnectorsSdk::Atlassian::Config.new(
      :cursors => cursors,
      :base_url => base_url
    )
  end
  let(:client_proc) do
    proc do
      ConnectorsSdk::ConfluenceCloud::CustomClient.new(
        :base_url => api_url,
        :access_token => access_token
      )
    end
  end

  subject do
    described_class.new(
      :content_source_id => content_source_id,
      :service_type => service_type,
      :config => config,
      :features => [],
      :client_proc => client_proc,
      :authorization_data_proc => proc { authorization_data }
    )
  end

  describe '#document_changes' do
    let!(:spaces_request) do
      stub_request(:get, "#{api_url}/rest/api/space").with(
        :query => {
          :start => 0,
          :limit => 50
        }
      ).to_return(
        :status => 200,
        :body => space_response.to_json,
        :headers => headers
      )
    end

    let!(:content_request) do
      stub_request(:get, "#{api_url}/rest/api/content/search").with(
        :query => {
          :cql => 'space="SWPRJ" AND type in (page,blogpost,attachment) order by created asc',
          :expand => '',
          :start => 0,
          :limit => 50
        }
      ).to_return(
        :status => 200,
        :body => content_response.to_json,
        :headers => headers
      )
    end

    let!(:expanded_content_request) do
      stub_request(:get, "#{api_url}/rest/api/content/10551886?status=any").with(
        :query => {
          :expand => %w(body.export_view history.lastUpdated ancestors space children.comment.body.export_view,container).join(',')
        }
      ).to_return(
        :status => 200,
        :body => expanded_content_response.to_json,
        :headers => headers
      )
    end

    it 'should make a request to the spaces' do
      subject.document_changes.to_a
      expect(spaces_request).to have_been_requested
      expect(subject.monitor.success_count).to eq(2)
    end

    it 'should make a request to the content' do
      subject.document_changes.to_a
      expect(content_request).to have_been_requested
      expect(subject.monitor.success_count).to eq(2)
    end

    context 'when a request returns a 504' do
      context 'from the "space" request' do
        let!(:spaces_request) do
          stub_request(:get, "#{api_url}/rest/api/space").with(
            :query => {
              :start => 0,
              :limit => 50
            }
          ).to_return(
            :status => 504,
            :body => '',
            :headers => headers
          )
        end

        it 'should raise a ConnectorsShared::TransientServerError' do
          expect { subject.document_changes { |c| } }.to raise_error(ConnectorsShared::TransientServerError)
          expect(subject.monitor.success_count).to eq(0)
          expect(subject.monitor.total_error_count).to eq(0) # error occurred outside of the single-document logic
        end
      end

      context 'from the "expanded content" request' do
        let!(:expanded_content_request) do
          stub_request(:get, "#{api_url}/rest/api/content/10551886?status=any").with(
            :query => {
              :expand => %w(body.export_view history.lastUpdated ancestors space children.comment.body.export_view,container).join(',')
            }
          ).to_return(
            :status => 504,
            :body => '',
            :headers => headers
          )
        end
        it 'should not raise' do
          expect { subject.document_changes.to_a }.to_not raise_error
          expect(subject.monitor.success_count).to eq(1)
          expect(subject.monitor.total_error_count).to eq(1) # error occurred inside of the single-document logic
        end
      end
    end

    context 'when modified_since is provided' do
      let(:modified_since) { 1.day.ago }

      let!(:content_request) do
        stub_request(:get, "#{api_url}/rest/api/content/search").with(
          :query => {
            :cql => "space=\"SWPRJ\" AND type in (page,blogpost,attachment) AND lastmodified > \"#{format_time(modified_since)}\" order by lastmodified asc",
            :expand => '',
            :start => 0,
            :limit => 50,
          }
        ).to_return(
          :status => 200,
          :body => content_response.to_json,
          :headers => headers
        )
      end

      it 'should make a request to the content lastmodified after the modified_since' do
        subject.document_changes(:modified_since => modified_since).to_a
        expect(content_request).to have_been_requested
        expect(subject.monitor.success_count).to eq(2)
      end
    end
  end

  describe '#yield_deleted_ids' do
    let(:fp_space_ids) { ['confluence_space_1234_delete_me', 'confluence_space_1234_keep_me'] }
    let(:space_ids) { fp_space_ids.map { |id| ConnectorsSdk::Confluence::Adapter.fp_id_to_confluence_space_id(id) } }
    let(:fp_content_ids) { ['confluence_content_1234_delete_me', 'confluence_content_1234_keep_me'] }
    let(:content_ids) { fp_content_ids.map { |id| ConnectorsSdk::Confluence::Adapter.fp_id_to_confluence_content_id(id) } }
    let(:fp_attachment_ids) { ['confluence_attachment_1234_delete_me', 'confluence_attachment_1234_keep_me'] }
    let(:attachment_ids) { fp_attachment_ids.map { |id| ConnectorsSdk::Confluence::Adapter.fp_id_to_confluence_attachment_id(id) } }

    let(:fp_ids) { fp_space_ids + fp_content_ids + fp_attachment_ids }

    before do
      allow(subject).to receive(:get_ids_for_deleted).with([], anything).and_return([])

      allow(subject).to receive(:get_ids_for_deleted).with(space_ids, :space).and_return([space_ids.first])
      allow(subject).to receive(:get_ids_for_deleted).with(content_ids, :content).and_return([content_ids.first])
      allow(subject).to receive(:get_ids_for_deleted).with(attachment_ids, :attachment).and_return([attachment_ids.first])
    end

    it 'yields deleted space id' do
      expect { |blk| subject.yield_deleted_ids(fp_space_ids, &blk) }.to yield_successive_args(fp_space_ids.first)
    end

    it 'yields deleted content id' do
      expect { |blk| subject.yield_deleted_ids(fp_content_ids, &blk) }.to yield_successive_args(fp_content_ids.first)
    end

    it 'yields deleted attachment id' do
      expect { |blk| subject.yield_deleted_ids(fp_attachment_ids, &blk) }.to yield_successive_args(fp_attachment_ids.first)
    end

    it 'yields a mix of ids' do
      expect { |blk| subject.yield_deleted_ids(fp_ids, &blk) }.to yield_successive_args(fp_space_ids.first, fp_content_ids.first, fp_attachment_ids.first)
    end
  end
end
