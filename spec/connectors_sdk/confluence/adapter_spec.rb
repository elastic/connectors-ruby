#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'support/shared_examples'
require 'fixtures/atlassian/confluence'

describe ConnectorsSdk::Confluence::Adapter do
  include ConnectorsSdk::Fixtures::Atlassian::Confluence

  let(:base_url) { 'https://swiftypedevelopment.atlassian.net/wiki' }

  describe '.swiftype_document_from_confluence_space' do
    let(:json) { Hashie::Mash.new(expanded_space_response) }
    let(:document) { described_class.swiftype_document_from_confluence_space(json, base_url) }

    it 'should work' do
      expect(document[:url]).to eq('https://swiftypedevelopment.atlassian.net/wiki/spaces/SWPRJ')
    end

    it 'should not yet produce a path' do
      expect(document[:path]).to be_nil
    end

    it_behaves_like 'does not populate updated_at'
  end

  describe '.swiftype_document_from_confluence_content' do
    let(:json) { Hashie::Mash.new(expanded_content_response) }
    let(:document) { described_class.swiftype_document_from_confluence_content(json, base_url) }

    it 'should work' do
      expect(document[:url]).to eq('https://swiftypedevelopment.atlassian.net/wiki/display/eng/Backups+Playbook')
    end

    it 'should not yet produce a path' do
      expect(document[:path]).to be_nil
    end

    it_behaves_like 'does not populate updated_at'
  end

  describe '.swiftype_document_from_confluence_attachment' do
    let(:json) { Hashie::Mash.new(expanded_attachment_response) }
    let(:document) { described_class.swiftype_document_from_confluence_attachment(json, base_url) }

    it 'should work' do
      expect(document[:url]).to eq('https://swiftypedevelopment.atlassian.net/wiki/spaces/TS/pages/32989/This+my+first+page?preview=%2F32989%2F33012%2Fcake.jpg')
    end

    it 'should produce a mime_type' do
      expect(document[:mime_type]).to eq('image/jpeg')
    end

    it 'should produce an extension' do
      expect(document[:extension]).to eq('jpg')
    end

    it 'should not yet produce a path' do
      expect(document[:path]).to be_nil
    end

    it_behaves_like 'does not populate updated_at'
  end
end
