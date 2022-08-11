# frozen_string_literal: true

require 'connectors/mongodb/connector'
require 'hashie/mash'
require 'spec_helper'

describe Connectors::MongoDB::Connector do
  subject { described_class.new(local_configuration: local_configuration, remote_configuration: remote_configuration) }
  let(:local_configuration) { {} }
  let(:remote_configuration) do
    {
       :host => {
         :label => 'MongoDB Server Hostname',
         :value => mongodb_host
       },
       :database => {
         :label => 'MongoDB Database',
         :value => mongodb_database
       },
       :collection => {
         :label => 'MongoDB Collection',
         :value => mongodb_collection
       }
    }
  end

  let(:mongodb_host) { '127.0.0.1:27027' }
  let(:mongodb_database) { 'sample-database' }
  let(:mongodb_collection) { 'some-collection' }

  let(:mongo_client) { double }

  let(:actual_collection) { double }
  let(:actual_collection_data) { [] }

  before(:each) do
    allow(Mongo::Client).to receive(:new).and_return(mongo_client)

    allow(mongo_client).to receive(:collections).and_return([Hashie::Mash.new({ :name => mongodb_collection })])
    allow(mongo_client).to receive(:database_names).and_return([Hashie::Mash.new({ :name => mongodb_database })])
    allow(mongo_client).to receive(:[]).with(mongodb_collection).and_return(actual_collection)

    allow(actual_collection).to receive(:find).and_return(actual_collection_data)
  end

  it_behaves_like 'a connector'

  context '#source_status' do
    it 'instantiates a mongodb client' do
      expect(Mongo::Client).to receive(:new).with([mongodb_host], hash_including(:database => mongodb_database))

      subject.source_status({})
    end
  end

  context '#yield_documents' do
    context 'when database is not found' do
      xit 'no error is raised' do
        # Leaving this here to describe the work of MongoDB client:
        # When database is not found on the server, the client does not raise errors
        # Instead, it acts as if a database exists on server, but has no collections
        # So every call to .collection will return empty iterator.
      end
    end

    context 'when collection is not found' do
      # mongo client does not raise an error when collection is not found on the server, instead it just returns an empty collection
      let(:actual_collection_data) { [] }

      it 'does not raise' do
        expect { |b| subject.yield_documents(&b) }.to_not raise_error(anything)
      end

      it 'does not yield' do
        expect { |b| subject.yield_documents(&b) }.to_not yield_with_args(anything)
      end
    end

    context 'when collection is found' do
      let(:actual_collection_data) do
        [
          { '_id' => '1', 'some' => { 'nested' => 'data' } },
          { '_id' => '2', 'more' => { 'nested' => 'data' } },
          { '_id' => '167', 'nothing' => nil },
          { '_id' => 'last' }
        ]
      end

      it 'yields each document of the collection replacing _id with id' do
        expected_ids = actual_collection_data.map { |d| d['_id'] }.to_a

        yielded_documents = []

        subject.yield_documents { |doc| yielded_documents << doc }

        expect(yielded_documents.size).to eq(actual_collection_data.size)
        expected_ids.each do |id|
          expect(yielded_documents).to include(a_hash_including('id' => id))
        end
      end
    end
  end
end
