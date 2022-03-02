#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/sharepoint/adapter'
require 'support/shared_examples'

describe Connectors::Sharepoint::Adapter do
  it 'should have id conversion functions set by generate_id_helpers' do
    expect(described_class.singleton_methods).to include(:share_point_id_to_fp_id)
    expect(described_class.singleton_methods).to include(:fp_id_to_share_point_id)
  end

  describe 'conversions to swiftype documents' do
    let(:created_by) { 'creator' }
    let(:created_at) { '2017-01-20T22:27:28Z' }
    let(:created_at_rfc3339) { Connectors::Base::Adapter.normalize_date(created_at) }
    let(:last_updated_by) { 'last modified by' }
    let(:last_updated_at) { '2017-01-20T22:27:28Z' }
    let(:last_updated_at_rfc3339) { Connectors::Base::Adapter.normalize_date(last_updated_at) }
    let(:title) { 'title.docx' }
    let(:url) { 'url.earl' }
    let(:drive_owner_name) { 'drive owner' }
    let(:parent_folder) { 'parent_folder' }
    let(:parent_path) { "/drives/eac871c1371902ee/root:/#{parent_folder}" }

    shared_examples_for(:graph_item) do
      let(:item_in_response) do
        Hashie::Mash.new(
          '@microsoft.graph.downloadUrl' => 'redacted',
          'createdBy' => {
            'user' => {
              'id' => '84e12774-eda7-44e6-a60c-2f0503213421',
              'displayName' => created_by,
            }
          },
          'createdDateTime' => created_at,
          'eTag' => '\'{639C8CBD-8747-411A-A8EA-ADF2E112828A},2\'',
          'id' => '01E4DADQ55RSOGGR4HDJA2R2VN6LQRFAUK',
          'lastModifiedBy' => {
            'user' => {
              'id' => '84e12774-eda7-44e6-a60c-2f0503213421',
              'displayName' => last_updated_by
            }
          },
          'lastModifiedDateTime' => last_updated_at,
          'name' => title,
          'webUrl' => url,
          'cTag' => '\'c:{639C8CBD-8747-411A-A8EA-ADF2E112828A},1\'',
          'file' => {
            'hashes' => {
              'quickXorHash' => '+cGREInTDPMUcusZfu+NjwDql9s='
            }
          },
          'parentReference' => {
            'driveId' => 'eac871c1371902ee',
            'id' => '01E4DADQ56Y2GOVW7725BZO354PWSELRRZ',
            'path' => parent_path
          },
          'size' => 10_880,
          'drive_owner_name' => drive_owner_name
        )
      end

      let(:expected_converted_hash) do
        {
          :_fields_to_preserve => described_class.fields_to_preserve,
          :id => 'share_point_01E4DADQ55RSOGGR4HDJA2R2VN6LQRFAUK',
          :path => "/#{parent_folder}/#{title}",
          :url => url,
          :type => type,
          :created_by => created_by,
          :created_at => created_at_rfc3339,
          :last_updated => last_updated_at_rfc3339,
          :updated_by => last_updated_by,
          :drive_owner => drive_owner_name
        }.merge(expected_fields).compact
      end

      let(:document) { described_class.public_send(swiftype_document_method, item_in_response) }

      it 'should have the correct fields' do
        expect(document).to eq(expected_converted_hash)
      end

      it_behaves_like 'does not populate updated_at'

      context 'when parent is the root' do
        let(:parent_path) { '/drives/eac871c1371902ee/root:' }

        it 'should correctly handle when the parent is the root' do
          expect(document[:path]).to eq("/#{title}")
        end
      end
    end

    describe '.swiftype_document_from_file' do
      let(:swiftype_document_method) { :swiftype_document_from_file }
      let(:type) { 'file' }
      let(:expected_fields) do
        {
          :title => title.sub('.docx', ''),
          :mime_type => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          :extension => 'docx'
        }
      end

      it_behaves_like(:graph_item)
    end

    describe '.swiftype_document_from_folder' do
      let(:swiftype_document_method) { :swiftype_document_from_folder }
      let(:type) { 'folder' }
      let(:expected_fields) do
        {
          :title => title
        }
      end

      it_behaves_like(:graph_item)
    end

    describe '.swiftype_document_from_package' do
      let(:swiftype_document_method) { :swiftype_document_from_package }
      let(:type) { 'oneNote' }
      let(:item_in_response) do
        Hashie::Mash.new(
          'createdBy' => {
            'user' => {
              'id' => '21003b46-e9a1-4eae-8b2f-78b61e4deac1',
              'displayName' => created_by
            }
          },
          'createdDateTime' => created_at,
          'eTag' => '\'{27A1EA78-7CCA-48F4-9851-D79DCEDC4C9D},1\'',
          'id' => '01Q7HJRADY5KQSPST46REJQUOXTXHNYTE5',
          'lastModifiedBy' => {
            'user' => {
              'id' => '3c636154-cc9a-44da-b207-ee46b6dbdd88',
              'displayName' => last_updated_by
            }
          },
          'lastModifiedDateTime' => last_updated_at,
          'name' => title,
          'webUrl' => url,
          'cTag' => '\'c:{B1F06591-9DB8-4EF3-9C78-E9F91312D081},2\'',
          'package' => {
            'type' => type
          },
          'parentReference' => {
            'driveId' => 'b!oj3_wlgSokuzZGcvT48FcA15OXewaoFDp0jo-NImzu9iL9GnnXziQI-2p4cAYd0I',
            'id' => '01E4DADQ7NCNZQA4IKNFA3JSI74WHGBE3J',
            'path' => parent_path
          },
          'size' => 5519,
          'drive_owner_name' => drive_owner_name
        )
      end

      let(:expected_converted_hash) do
        {
          :_fields_to_preserve => described_class.fields_to_preserve,
          :id => 'share_point_01Q7HJRADY5KQSPST46REJQUOXTXHNYTE5',
          :path => "/#{parent_folder}/#{title}",
          :title => title,
          :url => url,
          :type => 'onenote',
          :created_by => created_by,
          :created_at => created_at_rfc3339,
          :last_updated => last_updated_at_rfc3339,
          :updated_by => last_updated_by,
          :drive_owner => drive_owner_name
        }.compact
      end

      let(:document) { described_class.public_send(swiftype_document_method, item_in_response) }

      it 'should have the correct fields and correctly convert type from oneNote to onenote' do
        expect(document).to eq(expected_converted_hash)
      end
    end
  end
end
