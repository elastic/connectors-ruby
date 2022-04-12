#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/share_point/extractor'
require 'connectors_sdk/office365/custom_client'
require 'connectors_sdk/office365/config'

describe ConnectorsSdk::SharePoint::Extractor do
  let(:content_source_id) { BSON::ObjectId.new }
  let(:service_type) { 'sharepoint_online' }
  let(:access_token) { 'access_token' }
  let(:oauth_config) { { :client_id => 'client_id', :client_secret => 'client_secret' } }
  let(:authorization_data) { Hashie::Mash.new(:access_token => access_token, :expires_in => 3600) }
  let(:expires_at) { Time.now + 1.day }
  let(:config_drive_ids) { 'all' }
  let(:cursors) { nil }
  let(:config) do
    ConnectorsSdk::Office365::Config.new(
      :drive_ids => config_drive_ids,
      :index_permissions => false,
      :cursors => cursors
    )
  end
  let(:client_proc) do
    proc do
      ConnectorsSdk::Office365::CustomClient.new(
        :access_token => access_token,
        :cursors => cursors
      )
    end
  end

  let(:extractor) do
    described_class.new(
      :content_source_id => content_source_id,
      :service_type => service_type,
      :config => config,
      :features => [],
      :client_proc => client_proc,
      :authorization_data_proc => proc { authorization_data }
    )
  end

  subject { extractor }

  describe '#drive_ids' do
    let(:status) { 200 }
    let(:share_point_site_drive_ids) do
      [
        'b!xkMl9imzCk6WwcGgZfW-P6kl7SPuTVBHr7CsshR1pJmadPwhs0amQac8eamQOZxV',
        'b!zf_pedQFtUmNfOsMER8hjDFPnPGKQidGieFyNVg16OvoPJID7t_0Q6x3kR3OyckE'
      ]
    end
    let(:drive_ids) { share_point_site_drive_ids }
    let(:groups_url) { "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}groups/?$select=id,createdDateTime" }
    let(:sites_url) { "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}sites/?$select=id&search=&top=10" }
    let(:sites_body) { connectors_fixture_raw('office365/sites.json') }
    let(:site_1_id) { 'enterprisesearch.sharepoint.com,f62543c6-b329-4e0a-96c1-c1a065f5be3f,23ed25a9-4dee-4750-afb0-acb21475a499' }
    let(:site_2_id) { 'enterprisesearch.sharepoint.com,79e9ffcd-05d4-49b5-8d7c-eb0c111f218c,f19c4f31-428a-4627-89e1-72355835e8eb' }
    let(:site_1_drive_url) { "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}sites/#{site_1_id}/drives/?$select=id,owner,name,driveType" }
    let(:site_2_drive_url) { "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}sites/#{site_2_id}/drives/?$select=id,owner,name,driveType" }
    let(:site_drive_1_body) { connectors_fixture_raw('office365/site_drives_1.json') }
    let(:site_drive_2_body) { connectors_fixture_raw('office365/site_drives_2.json') }
    let(:groups_body) { connectors_fixture_raw('office365/groups.json') }
    let(:returned_drive_ids) do
      subject.send(:drives_to_index).map(&:id)
    end

    before(:each) do
      stub_request(:get, sites_url).to_return(:status => 200, :body => sites_body)
      stub_request(:get, site_1_drive_url).to_return(:status => 200, :body => site_drive_1_body)
      stub_request(:get, site_2_drive_url).to_return(:status => 200, :body => site_drive_2_body)
      stub_request(:get, groups_url).to_return(:status => 200, :body => groups_body)
    end

    context 'when drive ids are all' do
      it 'should grab all the drive ids' do
        expect(returned_drive_ids).to eq(drive_ids)
        expect(a_request(:get, sites_url)).to have_been_made
        expect(a_request(:get, site_1_drive_url)).to have_been_made
        expect(a_request(:get, site_2_drive_url)).to have_been_made
      end
    end

    context 'when drive ids are a specific set' do
      let(:config_drive_ids) { [share_point_site_drive_ids.first] }
      it 'should return those drive ids' do
        expect(returned_drive_ids).to eq(config_drive_ids)
      end
    end
  end

  describe '#yield_document_changes' do
    before(:each) do
      expect_sites([])
      expect_groups([])
    end

    context 'document-level permissions enabled' do
      before(:each) do
        allow(config).to(receive(:index_permissions).and_return(true))
      end

      it 'sets the document permissions if available' do
        site = expect_sites([random_site]).first
        drive = expect_site_drives(site[:id], [random_drive]).first
        root = expect_root_item(drive[:id], random_item)
        document = expect_item_children(drive[:id], root[:id], [random_document]).first
        permissions = expect_item_permissions(drive[:id], document[:id], [random_permission, random_permission, random_permission])

        subject.yield_document_changes do |_action, changed_document, _subextractors|
          expect(changed_document[ConnectorsShared::Constants::ALLOW_FIELD])
            .to(
              include(
                *permissions.map do |next_permission|
                  [
                    next_permission.dig(:grantedTo, :user, :displayName),
                    next_permission.dig(:grantedTo, :user, :id)
                  ]
                end.flatten
              )
            )
        end
      end

      it 'sets no deny permissions' do
        site = expect_sites([random_site]).first
        drive = expect_site_drives(site[:id], [random_drive]).first
        root = expect_root_item(drive[:id], random_item)
        document = expect_item_children(drive[:id], root[:id], [random_document]).first
        expect_item_permissions(drive[:id], document[:id], [random_permission])

        subject.yield_document_changes do |_action, changed_document, _subextractors|
          expect(changed_document[ConnectorsShared::Constants::DENY_FIELD]).to_not(be)
        end
      end

      it 'sets no permissions if none available' do
        site = expect_sites([random_site]).first
        drive = expect_site_drives(site[:id], [random_drive]).first
        root = expect_root_item(drive[:id], random_item)
        document = expect_item_children(drive[:id], root[:id], [random_document]).first
        expect_item_permissions(drive[:id], document[:id], [])

        subject.yield_document_changes do |_action, changed_document, _subextractors|
          expect(changed_document[ConnectorsShared::Constants::ALLOW_FIELD]).to_not(be)
          expect(document[ConnectorsShared::Constants::DENY_FIELD]).to_not(be)
        end
      end
    end

    context 'document-level permissions disabled' do
      before(:each) do
        allow(config).to(receive(:index_permissions).and_return(false))
      end

      it 'does not set permissions' do
        expect_site_with_documents

        subject.yield_document_changes do |_action, document, _subextractors|
          expect(document[ConnectorsShared::Constants::ALLOW_FIELD]).to_not(be)
          expect(document[ConnectorsShared::Constants::DENY_FIELD]).to_not(be)
        end
        expect(subject.monitor.success_count).to eq(1)
        expect(subject.monitor.total_error_count).to eq(0)
      end

      context 'documents fail' do
        before(:each) do
          subject.monitor = ConnectorsShared::Monitor.new(:connector => subject, :max_error_ratio => 1)
          allow(subject).to receive(:generate_document).once.and_raise('error')
        end

        it 'bypasses single document failures' do
          expect_site_with_documents

          expect { subject.document_changes { |c| c } }.to_not raise_error
          expect(subject.monitor.success_count).to eq(0)
          expect(subject.monitor.total_error_count).to eq(1)
        end
      end

      context 'incremental sync' do
        let(:modified_since) { Time.parse('2017-01-01T00:00:06Z') }

        it 'yields document' do
          expect_site_with_documents

          subject.document_changes(:modified_since => modified_since) { |c| c }
          expect(subject.monitor.success_count).to eq(1)
          expect(subject.monitor.total_error_count).to eq(0)
        end
      end

      context 'with cursor' do
        let(:drive_id) { random_string }
        let(:cursors) { { 'drive_ids' => { drive_id => "#{graph_base_url}drives/#{drive_id}/root/delta" } } }

        it 'yields document' do
          site = expect_sites([random_site]).first
          drive = expect_site_drives(site[:id], [random_drive.tap { |d| d[:id] = drive_id }]).first
          expect_delta(drive[:id], [random_change.tap { |d| d[:id] = drive_id }])

          subject.document_changes { |c| c }
          expect(subject.monitor.success_count).to eq(1)
          expect(subject.monitor.total_error_count).to eq(0)
        end
      end

      def expect_site_with_documents
        site = expect_sites([random_site]).first
        drive = expect_site_drives(site[:id], [random_drive]).first
        root = expect_root_item(drive[:id], random_item)
        expect_item_children(drive[:id], root[:id], [random_document])
        expect_delta(drive[:id], [random_change])
      end
    end

    context 'filters out unused drive types' do
      it 'when personal' do
        assert_drive_filtered(random_personal_drive)
      end

      it 'when business' do
        assert_drive_filtered(random_business_drive)
      end

      def assert_drive_filtered(drive)
        site = expect_sites([random_site]).first
        expect_site_drives(site[:id], [drive])
        expect_item_children(
          drive[:id],
          expect_root_item(drive[:id], random_item)[:id],
          [random_document]
        )

        expect { subject.document_changes { |c| c } }.to_not raise_error

        expect(subject.monitor.success_count).to eq(0)
        expect(subject.monitor.total_error_count).to eq(0)
      end
    end
  end

  describe '#yield_deleted_ids' do
    let(:document_id) { 'document_id' }

    before(:each) do
      site = expect_sites([random_site]).first
      drive = expect_site_drives(site[:id], [random_drive]).first
      root = expect_root_item(drive[:id], random_item)
      expect_groups([])
      expect_item_children(drive[:id], root[:id], [random_document.tap { |document| document[:id] = document_id }])
    end

    context 'with removed item' do
      let(:ids) { [subject.send(:convert_id_to_fp_id, 'removed_id')] }

      it 'yields the deleted item id' do
        expect { |blk| subject.yield_deleted_ids(ids, &blk) }.to yield_successive_args(ids.first)
      end
    end

    context 'with no item removed' do
      let(:ids) { [subject.send(:convert_id_to_fp_id, document_id)] }

      it 'yields nothing' do
        expect { |blk| subject.yield_deleted_ids(ids, &blk) }.to yield_successive_args
      end
    end
  end

  context 'break_after_page' do
    describe '#yield_document_changes' do
      let(:cursors) { {} }
      let(:block) {
        lambda do |args|
          # no-op
        end
      }
      let(:site_id) { 'site_01' }
      let(:drives) { [{ :id => drive_id, :driveType => 'documentLibrary' }] }
      let(:drive_id) { 'drive_01' }

      subject { super().yield_document_changes(:break_after_page => true, &block) }

      before(:each) do
        expect_sites([:id => site_id])
        expect_groups([])
        expect_site_drives(site_id, drives)
        allow(extractor).to receive(:retrieve_latest_cursors).and_return({ described_class::DRIVE_IDS_CURSOR_KEY => {} })
      end

      it 'does not error' do
        cursors['current_drive_id'] = ('z' * 100) # sorts after any real id
        expect { subject }.not_to raise_error
      end

      it 'preserves current_drive_id in the presence of a page_cursor' do
        cursors['current_drive_id'] = drive_id
        allow(extractor).to receive(:yield_drive_items) do |_args|
          config.cursors['page_cursor'] = '_'
        end

        expect { subject }.to change { cursors }.from({ 'current_drive_id' => drive_id, 'drive_ids' => {} }).to({ 'current_drive_id' => drive_id, 'page_cursor' => '_', 'drive_ids' => {} })
      end

      it 'sets completed to true in the absence of a page_cursor' do
        cursors['current_drive_id'] = drive_id
        allow(extractor).to receive(:yield_drive_items)

        expect { subject }.to change { extractor.completed }.from(false).to(true)
      end
    end
  end

  def expect_item_children(drive_id, item_id, children)
    stub_request(:get, "#{graph_base_url}drives/#{drive_id}/items/#{item_id}/children")
      .to_return(graph_response({ value: children }))
    children
  end

  def expect_item_permissions(drive_id, item_id, permissions)
    stub_request(:get, "#{graph_base_url}drives/#{drive_id}/items/#{item_id}/permissions")
      .to_return(graph_response({ value: permissions }))
    permissions
  end

  def expect_root_item(drive_id, root_item)
    stub_request(:get, "#{graph_base_url}drives/#{drive_id}/root?$select=id")
      .to_return(graph_response({ id: root_item[:id] }))
    root_item
  end

  def expect_sites(sites)
    stub_request(:get, "#{graph_base_url}sites/?$select=id&search=&top=10")
      .to_return(graph_response({ value: sites }))

    sites
  end

  def expect_groups(groups)
    stub_request(:get, "#{graph_base_url}groups/?$select=id,createdDateTime")
      .to_return(graph_response(:value => groups))

    groups
  end

  def expect_site_drives(site_id, drives)
    stub_request(:get, "#{graph_base_url}sites/#{site_id}/drives/?$select=id,owner,name,driveType")
      .to_return(graph_response(:value => drives))
    drives
  end

  def expect_group_drives(group_id, drives)
    stub_request(:get, "#{graph_base_url}sites/#{group_id}/drives/?$select=id,owner,name,driveType")
      .to_return(graph_response(:value => drives))
    drives
  end

  def expect_delta(drive_id, drives)
    stub_request(:get, "#{graph_base_url}drives/#{drive_id}/root/delta?$select=id,content.downloadUrl,lastModifiedDateTime,lastModifiedBy,root,deleted,file,folder,package,name,webUrl,createdBy,createdDateTime,size")
      .to_return(graph_response(:value => drives))
    drives
  end

  def graph_response(body)
    {
      :status => 200,
      :body => body.to_json
    }
  end

  def random_document
    {
      :id => random_string,
      :file => true,
      :name => "#{random_string}.docx"
    }
  end

  def random_drive
    {
      :id => random_string,
      :description => random_string,
      :driveType => 'documentLibrary',
      :name => random_string,
      :owner => {
        :user => {
          :displayName => random_string
        }
      }
    }
  end

  def random_business_drive
    drive = random_drive
    drive[:driveType] = 'business'
    drive
  end

  def random_personal_drive
    drive = random_drive
    drive[:driveType] = 'personal'
    drive
  end

  def random_item
    {
      :id => random_string
    }
  end

  def random_permission
    {
      :grantedTo => {
        :user => {
          :displayName => random_string,
          :id => random_string
        }
      }
    }
  end

  def random_site
    {
      :id => random_string,
      :name => random_string,
      :owner => {
        :user => {
          :displayName => random_string
        }
      }
    }
  end

  def random_change
    {
      :id => random_string,
      :lastModifiedDateTime => Time.now,
      :name => 'foo.txt',
      :file => {}
    }
  end

  def graph_base_url
    ConnectorsSdk::Office365::CustomClient::BASE_URL
  end
end
