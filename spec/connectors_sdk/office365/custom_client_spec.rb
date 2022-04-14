#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/custom_client'

describe ConnectorsSdk::Office365::CustomClient do
  let(:access_token) { 'access_token' }
  let(:cursors) { {} }
  let(:client) do
    ConnectorsSdk::Office365::CustomClient.new(
      :access_token => access_token,
      :cursors => cursors,
      :ensure_fresh_auth => lambda do |client|
        if Time.now >= authorization_details.fetch(:expires_at) - 2.minutes
          client.update_auth_data!(access_token)
        end
      end
    )
  end

  let(:service_type) { 'share_point' }
  let(:authorization_details) do
    {
      :authorization_data => authorization_data,
      :expires_at => expires_at
    }
  end
  let(:authorization_data) do
    {
      'access_token' => 'access_token'
    }
  end
  let(:expires_at) { Time.now + 1.day }

  describe '#request' do
    let(:status) { 200 }
    let(:body) { connectors_fixture_raw('office365/drives.json') }

    before(:each) do
      stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'drives/')
        .to_return(:status => status, :body => body)
    end

    context 'with good response' do
      it 'should be successful' do
        expect { client.send(:request_endpoint, :endpoint => 'drives/') }.to_not raise_error
      end

      context 'auth details are expired' do
        let(:expires_at) { Time.now - 1.day }

        it 'will refresh auth on an http call' do
          expect(client).to receive(:update_auth_data!).and_call_original

          client.send(:request_endpoint, :endpoint => 'drives/')
        end
      end
    end

    context 'when office 365 500s and an error message' do
      let(:status) { 500 }
      let(:body) { connectors_fixture_raw('office365/error.json') }

      it 'should throw error with fallback error message of status code explanation' do
        # yes, MSFT does not use spell check
        expect { client.send(:request_endpoint, :endpoint => 'drives/') }
          .to raise_error(ConnectorsSdk::Office365::CustomClient::ClientError)
          .with_message(/All the offeractions povided in the property bag cannot be validated for the token/)
      end
    end
  end

  it 'retries on a 429 response' do
    stubbed_request = stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'drives/')
      .to_return(:status => 429, :body => connectors_fixture_raw('office365/429.json')).then
      .to_return({ body: connectors_fixture_raw('office365/drives.json') })

    client.send(:request_endpoint, :endpoint => 'drives/')

    expect(stubbed_request).to have_been_requested.twice
  end

  describe '#sites' do
    let(:first_page_url) { "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}sites/?search=&top=10" }
    let(:first_page_body) { connectors_fixture_raw('office365/sites_with_nextlink.json') }
    let(:second_page_url) { "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}sites/?$skiptoken=s!MTA7ZWZiOTI5MzAtNzAyYy00Yjg2LWI1ODUtN2UyNTViNzBlMjM1&search=&top=10" }
    let(:second_page_body) { connectors_fixture_raw('office365/sites.json') }

    it 'should correctly page through and return all sites' do
      first_page = stub_request(:get, first_page_url).to_return(:status => 200, :body => first_page_body)
      second_page = stub_request(:get, second_page_url).to_return(:status => 200, :body => second_page_body)
      expect(client.sites.length).to eq(12)
      assert_requested(first_page)
      assert_requested(second_page)
    end
  end

  describe '#group_drive' do
    let(:group_id) { 'ed5f8403-cc9b-40bf-9adc-5642238447ab' }
    let(:status) { 200 }
    let(:directory) { 'office365/share_point_drives/' }
    let(:private_group_drive_body) { connectors_fixture_raw(directory + 'group_drive_private.json') }

    before(:each) do
      stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + "groups/#{group_id}/drive/")
        .to_return(:status => status, :body => private_group_drive_body)
    end
  end

  describe '#share_point_drives' do
    let(:status) { 200 }
    let(:directory) { 'office365/share_point_drives/' }
    let(:time_within_azure_permission_sync_sla) { '2021-05-04T06:15:29Z' }
    let(:time_outside_azure_permission_sync_sla) { '2022-05-25T06:12:29Z' }

    let(:groups_mapped_body) { connectors_fixture_raw(directory + 'group_ids_with_created_date_time.json') }
    let(:private_group_site_id_body) { connectors_fixture_raw(directory + 'group_root_site_id.json') } # returns 1 result
    let(:public_site_drives_body) { connectors_fixture_raw(directory + 'site_drives_for_site_created_long_time_ago.json') } # returns 1 result
    let(:recent_site_drives_body) { connectors_fixture_raw(directory + 'site_drives_for_recently_created_site.json') } # returns 2 results

    before(:each) do
      stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'groups/?$select=id,createdDateTime')
        .to_return(:status => status, :body => groups_mapped_body)

      stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'groups/ed5f8403-cc9b-40bf-9adc-5642238447ab/sites/root?$select=id')
        .to_return(:status => status, :body => private_group_site_id_body)

      stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'sites/enterprisesearch.sharepoint.com,afb9d6f1-1ae4-422a-aea6-ea1965f7b854,91dd91fc-e210-4be2-b41f-7f1dbedb969c/drives/')
        .to_return(:status => status, :body => public_site_drives_body)

      stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'sites/enterprisesearch.sharepoint.com,faa5f9e1-9b38-4f39-8c54-9cf2f09757bf,6b426e38-f1ef-4740-aa12-785d56595942/drives/')
        .to_return(:status => status, :body => recent_site_drives_body)
    end

    context 'before private group permissions were synchronized' do
      let(:site_ids_body) { connectors_fixture_raw(directory + 'sites_select_ids_before_permission_sync.json') }

      before(:each) do
        stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'sites/?$select=id&search=&top=10')
          .to_return(:status => status, :body => site_ids_body)
      end

      context 'private group was created within 24 hours from now' do
        it 'should return both drive from /sites/ endpoint and /groups/ endpoint' do
          Timecop.freeze(time_within_azure_permission_sync_sla) do
            drives = client.share_point_drives

            expect(drives.length).to eq(2)
          end
        end
      end
    end

    context 'after private group has already synchronized permissions' do
      let(:site_ids_body) { connectors_fixture_raw(directory + 'sites_select_ids_after_permission_sync.json') }

      before(:each) do
        stub_request(:get, ConnectorsSdk::Office365::CustomClient::BASE_URL + 'sites/?$select=id&search=&top=10')
          .to_return(:status => status, :body => site_ids_body)
      end

      context 'private group was created within 24 hours from now' do
        it 'should return drives with unique ids' do
          Timecop.freeze(time_within_azure_permission_sync_sla) do
            drives = client.share_point_drives
            unique_drive_ids = drives.map(&:id)
              .uniq

            expect(drives.length).to eq(unique_drive_ids.length)
          end
        end
      end

      context 'private group was created more than 24 hours ago' do
        it 'should return both public sites' do
          Timecop.freeze(time_outside_azure_permission_sync_sla) do
            drives = client.share_point_drives

            expect(drives.length).to eq(2)
          end
        end
      end
    end
  end

  context 'break_after_page' do
    describe '#list_items' do
      let(:drive_id) { 'drive_01' }
      let(:block) {
        lambda do |item|
          # no-op
        end
      }
      let(:folder_ids) { ['folder1', 'folder2'] }

      subject { client.list_items(drive_id, :break_after_page => true, &block) }

      before(:each) do
        client.cursors['page_cursor'] = folder_ids
        folder_ids.each do |folder_id|
          stub_request(:get, "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}drives/#{drive_id}/items/#{folder_id}/children").to_return(:status => 200, :body => { 'value' => [] }.to_json)
        end
      end

      it 'should not error' do
        expect { subject }.not_to raise_error
      end

      it 'should clear page_cursor' do
        expect { subject }.to change { client.cursors }.to({ 'drive_ids' => {} })
      end

      it 'should break after first folder returns over 100 items' do
        value = (1..100).to_a.map do |i|
          Hashie::Mash.new(:id => i, :folder => false)
        end
        stub_request(:get, "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}drives/#{drive_id}/items/#{folder_ids.last}/children").to_return(:status => 200, :body => { 'value' => value }.to_json)

        expect { subject }.to change { client.cursors }.to({ 'drive_ids' => {}, 'page_cursor' => Array.wrap(folder_ids.first) })
      end

      it 'will save current folder for next request in presence of item_children_next_link' do
        value = (1..100).to_a.map do |i|
          Hashie::Mash.new(:id => i, :folder => false)
        end
        stub_request(:get, "#{ConnectorsSdk::Office365::CustomClient::BASE_URL}drives/#{drive_id}/items/#{folder_ids.last}/children").to_return(:status => 200, :body => { 'value' => value, '@odata.nextLink' => '_' }.to_json)

        expect { subject }.to change { client.cursors }.to({ 'drive_ids' => {}, 'page_cursor' => folder_ids, 'item_children_next_link' => '_' })
      end
    end

    describe '#list_changes' do
      let(:drive_id) { 'drive_01' }
      let(:block) {
        lambda do |item|
          # no-op
        end
      }
      let(:page_cursor_url) { 'https://www.example.com' }
      let(:new_page_cursor_url) { "#{page_cursor_url}/new" }

      subject { client.list_changes(:drive_id => drive_id, :break_after_page => true, &block) }

      before(:each) do
        client.cursors['page_cursor'] = page_cursor_url
        stub_request(:get, page_cursor_url).to_return(:status => 200, :body => { 'value' => [] }.to_json)
      end

      it 'should not error' do
        expect { subject }.not_to raise_error
      end

      it 'should clear page_cursor' do
        expect { subject }.to change { client.cursors['page_cursor'] }.from(page_cursor_url).to(nil)
      end

      it 'should break after the response returns over 100 items' do
        value = (1..100).to_a.map do |_i|
          Hashie::Mash.new(:root => false)
        end
        stub_request(:get, page_cursor_url).to_return(:status => 200, :body => { 'value' => value, '@odata.nextLink' => new_page_cursor_url }.to_json)

        expect { subject }.to change { client.cursors['page_cursor'] }.from(page_cursor_url).to(new_page_cursor_url)
      end
    end
  end
end
