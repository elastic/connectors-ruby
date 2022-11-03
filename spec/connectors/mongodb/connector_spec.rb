# frozen_string_literal: true

require 'connectors/mongodb/connector'
require 'hashie/mash'
require 'spec_helper'

describe Connectors::MongoDB::Connector do
  subject { described_class.new(configuration: configuration) }
  let(:configuration) do
    {
       :host => {
         :label => 'Server Hostname',
         :value => mongodb_host
       },
       :database => {
         :label => 'Database',
         :value => mongodb_database
       },
       :collection => {
         :label => 'Collection',
         :value => mongodb_collection
       },
       :user => {
         :label => 'Username',
         :value => mongodb_username
       },
       :password => {
         :label => 'Password',
         :value => mongodb_password
       },
       :direct_connection => {
         :label => 'Direct connection? (true/false)',
         :value => direct_connection
       }
    }
  end

  let(:mongodb_host) { '127.0.0.1:27027' }
  let(:mongodb_database) { 'sample-database' }
  let(:mongodb_collection) { 'some-collection' }
  let(:mongodb_username) { nil }
  let(:mongodb_password) { nil }
  let(:direct_connection) { 'false' }

  let(:mongo_client) { double }

  let(:actual_collection) { double }
  let(:actual_collection_data) { [] }
  let(:actual_collection_name) { 'sample-collection' }
  let(:actual_collection_names) { [actual_collection_name] }
  let(:mongo_collection_cursor) { double }
  let(:mongo_collection_data) { [] }
  let(:actual_database) { double }
  let(:actual_database_names) { ['sample-database'] }

  before(:each) do
    allow(Mongo::Client).to receive(:new).and_yield(mongo_client)

    allow(mongo_client).to receive(:collections).and_return([Hashie::Mash.new({ :name => mongodb_collection })])
    allow(mongo_client).to receive(:database_names).and_return([Hashie::Mash.new({ :name => mongodb_database })])
    allow(mongo_client).to receive(:[]).with(mongodb_collection).and_return(actual_collection)
    allow(mongo_client).to receive(:with).and_return(mongo_client)
    allow(mongo_client).to receive(:close)

    allow(actual_database).to receive(:collection_names).and_return(actual_collection_names)
    allow(actual_collection).to receive(:find).and_return(mongo_collection_cursor)

    allow(mongo_collection_cursor).to receive(:skip).and_return(mongo_collection_cursor)
    allow(mongo_collection_cursor).to receive(:limit).and_return(mongo_collection_data)
  end

  it_behaves_like 'a connector'

  shared_examples_for 'handles auth' do
    context 'when username and password are provided' do
      let(:mongodb_username) { 'admin' }
      let(:mongodb_password) { 'some-password' }
      it 'sets client to use basic auth' do
        expect(Mongo::Client).to receive(:new).with(anything, hash_including(:user => mongodb_username, :password => mongodb_password))

        do_test
      end
    end

    context 'when no username and password are provided' do
      it 'does not set client to use basic auth' do
        expect(Mongo::Client).to_not receive(:new).with(anything, hash_including(:user => mongodb_username, :password => mongodb_password))

        do_test
      end
    end
  end

  shared_examples_for 'validates direct_connection' do
    %w[true false].each do |value|
      context "when direct_connection is #{value}" do
        let(:direct_connection) { value }

        it 'does not throw error' do
          expect { do_test }.to_not raise_error
        end
      end
    end

    context 'when direct_connection is not a boolean' do
      let(:direct_connection) { 'foobar' }

      it 'throws error' do
        expect { do_test }.to raise_error
      end
    end
  end

  context '#is_healthy?' do
    it_behaves_like 'handles auth' do
      let(:do_test) { subject.is_healthy? }
    end

    it 'instantiates a mongodb client' do
      expect(Mongo::Client).to receive(:new).with(mongodb_host, hash_including(:database => mongodb_database))

      subject.is_healthy?
    end
  end

  context '#yield_documents' do
    it_behaves_like 'handles auth' do
      let(:do_test) { subject.yield_documents { |doc|; } }
    end
    it_behaves_like 'validates direct_connection' do
      let(:do_test) { subject.yield_documents { |doc|; } }
    end

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
      context 'when data is distributed in multiple pages' do
        let(:page_size) { 3 }

        let(:first_page_data) do
          [
            { '_id' => '1', 'some' => { 'nested' => 'data' } },
            { '_id' => '2', 'more' => { 'nested' => 'data' } },
            { '_id' => '167', 'nothing' => nil }
          ]
        end

        let(:second_page_data) do
          [
            { '_id' => 'last' }
          ]
        end

        let(:third_page_data) do
          []
        end

        let(:all_data) { first_page_data + second_page_data + third_page_data }

        let(:second_page_cursor) { double }
        let(:third_page_cursor) { double }

        before(:each) do
          stub_const('Connectors::MongoDB::Connector::PAGE_SIZE', page_size)
          allow(mongo_collection_cursor).to receive(:skip).with(0).and_return(mongo_collection_cursor)
          allow(mongo_collection_cursor).to receive(:limit).and_return(first_page_data)

          allow(mongo_collection_cursor).to receive(:skip).with(page_size).and_return(second_page_cursor)
          allow(second_page_cursor).to receive(:limit).and_return(second_page_data)

          allow(mongo_collection_cursor).to receive(:skip).with(page_size * 2).and_return(third_page_cursor)
          allow(third_page_cursor).to receive(:limit).and_return(third_page_data)
        end

        it 'fetches each page' do
          # a bit weird test, but I did not figure out to do a better job ensuring that each page was fetched
          expect(mongo_collection_cursor).to receive(:limit).once
          expect(second_page_cursor).to receive(:limit).once
          expect(third_page_cursor).to receive(:limit).once

          subject.yield_documents { |doc|; }
        end

        it 'yields each document of the collection remapping ids correctly scrolling through pages' do
          expected_ids = all_data.map { |d| d['_id'] }.to_a

          yielded_documents = []

          subject.yield_documents { |doc| yielded_documents << doc }

          expect(yielded_documents.size).to eq(all_data.size)
          expected_ids.each do |id|
            expect(yielded_documents).to include(a_hash_including('id' => id))
          end
        end
      end

      context 'when field of type BSON::ObjectId is met' do
        let(:id) { '63238d68dc461bfe327e9634' }

        let(:actual_collection_data) do
          [
            { '_id' => BSON::ObjectId.from_string(id) }
          ]
        end

        it 'serializes the field correctly' do
          # only 1 record is there, so meh no need to do it outside of yield_documents
          subject.yield_documents do |doc|
            expect(doc['id']).to eq(id)
          end
        end
      end

      context 'when field of type BSON::Decimal128 is met' do
        let(:price) { '12.00' }

        let(:actual_collection_data) do
          [
            { '_id' => 1, 'price' => BSON::Decimal128.from_string(price) }
          ]
        end

        it 'serializes the field correctly' do
          # only 1 record is there, so meh no need to do it outside of yield_documents
          subject.yield_documents do |doc|
            expect(doc['price']).to eq(BigDecimal(price))
          end
        end
      end

      context 'when array of strings is met' do
        let(:array_of_strings) { ['1', '1b', '17', '222'] }
        let(:actual_collection_data) do
          [
            { '_id' => 1, 'rooms' => array_of_strings }
          ]
        end

        it 'serializes the field correctly' do
          # only 1 record is there, so meh no need to do it outside of yield_documents
          subject.yield_documents do |doc|
            expect(doc['rooms']).to eq(array_of_strings)
          end
        end
      end

      context 'when field that needs special serialization is nested in hash' do
        let(:price) { '12.00' }
        let(:actual_collection_data) do
          [
            { '_id' => 1, 'room' => { 'price' => BSON::Decimal128.from_string(price) } }
          ]
        end

        it 'serializes the field correctly' do
          # only 1 record is there, so meh no need to do it outside of yield_documents
          subject.yield_documents do |doc|
            expect(doc['room']['price']).to eq(BigDecimal(price))
          end
        end
      end

      context 'when field that needs special serialization is nested in array' do
        let(:price) { '12.00' }
        let(:actual_collection_data) do
          [
            { '_id' => 1, 'rooms' => [{ 'price' => BSON::Decimal128.from_string(price) }] }
          ]
        end

        it 'serializes the field correctly' do
          # only 1 record is there, so meh no need to do it outside of yield_documents
          subject.yield_documents do |doc|
            expect(doc['rooms'][0]['price']).to eq(BigDecimal(price))
          end
        end
      end
    end
  end
end
