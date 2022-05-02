#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'connectors_sdk/confluence/custom_client'
require 'connectors_sdk/confluence_cloud/custom_client'

describe ConnectorsSdk::ConfluenceCloud::CustomClient do
  let(:client) do
    ConnectorsSdk::ConfluenceCloud::CustomClient.new(
      :base_url => 'https://api.atlassian.com/ex/confluence/abc123',
      :access_token => 'access_token',
      :basic_auth_token => nil
    )
  end

  it 'inherits from Confluence' do
    expect(client.class.superclass).to eq(ConnectorsSdk::Confluence::CustomClient)
  end
end
