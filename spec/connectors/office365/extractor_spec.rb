#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/office365/config'
require 'connectors/office365/custom_client'
require 'connectors/office365/extractor'

describe Connectors::Office365::Extractor do
  let(:content_source_id) { BSON::ObjectId.new }
  let(:service_type) { 'sharepoint_online' }
  let(:access_token) { 'access_token' }
  let(:oauth_config) { { :client_id => 'client_id', :client_secret => 'client_secret' } }
  let(:authorization_data) { Hashie::Mash.new(:access_token => access_token, :expires_in => 3600) }
  let(:expires_at) { Time.now + 1.day }
  let(:config_drive_ids) { 'all' }
  let(:cursors) { nil }
  let(:config) do
    Connectors::Office365::Config.new(
      :drive_ids => config_drive_ids,
      :index_permissions => false,
      :cursors => cursors
    )
  end
  let(:client_proc) do
    proc do
      Connectors::Office365::CustomClient.new(
        :access_token => access_token,
        :cursors => cursors
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

  describe '#yield_permissions' do
    it 'gets the group permissions for a user' do
      groups = 2.times.collect { random_group }
      user_id = expect_user_groups(random_string, groups)
      expect_owned_groups(user_id, [])

      expect_permissions_include(user_id, groups.map { |next_group| "#{next_group.displayName} Members" })
    end

    it 'gets the owned group permissions for a user' do
      groups = 2.times.collect { random_group }
      user_id = expect_owned_groups(random_string, groups)
      expect_user_groups(user_id, [])

      expect_permissions_include(user_id, groups.map { |next_group| "#{next_group.displayName} Members" })
    end

    it 'filters out non-group owned objects' do
      user_id = expect_owned_groups(random_string, [{ :id => 'blah' }])
      expect_user_groups(user_id, [])

      actual_permissions = expect_permissions_include(user_id, [user_id])
      expect(actual_permissions.size).to(eq(1))
    end

    it 'adds a permission for the user itself' do
      user_id = expect_user_groups(random_string, [])
      expect_owned_groups(user_id, [])

      actual_permissions = nil
      subject.yield_permissions(user_id) do |permissions|
        actual_permissions = permissions
      end
      expect(actual_permissions).to(eq([user_id]))
    end

    it 'fails if the user groups cannot be fetched' do
      user_id = random_string
      when_user_groups(user_id).and_return(status: 500)

      expect {
        subject.yield_permissions(user_id)
      }.to(raise_error(Connectors::Office365::CustomClient::ClientError))
    end

    it 'yields empty permissions if user is deleted' do
      user_id = random_string
      when_user_groups(user_id).and_return(status: 404)

      actual_permissions = nil
      subject.yield_permissions(user_id) do |permissions|
        actual_permissions = permissions
      end
      expect(actual_permissions).to be_empty
    end

    def expect_owned_groups(user_id, groups)
      stub_request(:get, "#{graph_base_url}users/#{user_id}/ownedObjects?$select=id,displayName")
        .to_return(graph_response({ value: groups }))
      user_id
    end

    def expect_permissions_include(user_id, expected_permissions)
      actual_permissions = nil
      subject.yield_permissions(user_id) do |permissions|
        actual_permissions = permissions
      end
      expect(actual_permissions).to(include(*expected_permissions))
      actual_permissions
    end

    def expect_user_groups(user_id, groups)
      when_user_groups(user_id)
        .to_return(graph_response({ value: groups }))
      user_id
    end

    def graph_base_url
      Connectors::Office365::CustomClient::BASE_URL
    end

    def graph_response(body)
      {
        :status => 200,
        :body => body.to_json
      }
    end

    def random_group
      Hashie::Mash.new({
                         '@odata.type' => '#microsoft.graph.group',
                         :id => random_string,
                         :displayName => random_string
                       })
    end

    def when_user_groups(user_id)
      stub_request(:get, "#{graph_base_url}users/#{user_id}/transitiveMemberOf?$select=id,displayName")
    end
  end
end
