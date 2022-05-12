#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/confluence_cloud/http_call_wrapper'

describe ConnectorsSdk::ConfluenceCloud::HttpCallWrapper do
  describe '.secrets' do
    context 'when secrets are equivalent' do
      let(:params) do
        {
          :secret => 'secret',
          :other_secret => 'secret'
        }
      end

      it 'returns true' do
        expect(subject.secrets(params)[:equivalent]).to be_truthy
      end
    end

    context 'when secrets are not equivalent' do
      let(:params) do
        {
            :secret => 'secret',
            :other_secret => 'other_secret'
        }
      end

      it 'returns false' do
        expect(subject.secrets(params)[:equivalent]).to be_falsey
      end
    end
  end
end
