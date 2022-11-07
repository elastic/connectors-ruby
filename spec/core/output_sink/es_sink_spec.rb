require 'core/output_sink/es_sink'
require 'core/connector_settings'
require 'utility/es_client'

require 'spec_helper'

RSpec::Matchers.define :array_of_size do |x|
  match { |actual| actual.size == x }
end

describe Core::OutputSink::EsSink do
  subject { described_class.new(index_name, request_pipeline, bulk_queue) }
  let(:index_name) { 'some-index-name' }
  let(:request_pipeline) { Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE }
  let(:es_client) { double }
  let(:bulk_queue) { double }
  let(:serializer) { double }

  before(:each) do
    allow(Utility::EsClient).to receive(:new).and_return(es_client)

    allow(es_client).to receive(:bulk)

    # I attempted to test with this class mocked but it just made things much much harder
    allow(bulk_queue).to receive(:will_fit?).and_return(true)
    allow(bulk_queue).to receive(:add)
    allow(bulk_queue).to receive(:pop_all)

    allow(Elasticsearch::API).to receive(:serializer).and_return(serializer)
    allow(serializer).to receive(:dump).and_return('')
  end

  it_behaves_like 'implements all private methods of base class' do
    let(:concrete_class_instance) { subject }
    let(:base_class_instance) { Core::OutputSink::BaseSink.new }
  end

  context '.ingest' do
    let(:document) do
      {
        :id => 1,
        'text' => 'hoho, haha!'
      }
    end
    let(:serialized_document) { 'id: 1, text: "hoho, haha!"' }

    before(:each) do
      allow(serializer).to receive(:dump).with(document).and_return(serialized_document)
    end

    context('when bulk queue still has capacity') do
      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.ingest(document)
      end
    end

    context 'when bulk queue reports that it is full' do
      let(:document) do
        {
          :id => 1,
          'text' => 'hoho, haha!'
        }
      end
      let(:another_document) do
        {
          :id => 2,
          :text => 'work work!'
        }
      end 
      let(:serialized_document) { 'id: 1, text: "hoho, haha!"' }
      let(:another_serialized_document) { 'id: 2, text: "work work!"' }

      before(:each) do
        # emulated behaviour is:
        # Queue will be full once first item is added to it
        allow(bulk_queue).to receive(:will_fit?).and_return(true, false)
        allow(bulk_queue).to receive(:pop_all).and_return([ serialized_document ])

        allow(serializer).to receive(:dump).with(document).and_return(serialized_document)
        allow(serializer).to receive(:dump).with(another_document).and_return(another_serialized_document)
      end

      it 'sends a bulk request with data returned from bulk queue' do
        expect(es_client).to receive(:bulk)
          .once

        subject.ingest(document)
        subject.ingest(another_document)
      end

      it 'pops existing documents before adding a new one' do
        expect(bulk_queue).to receive(:add)
          .with(anything, serialized_document)
          .ordered

        expect(bulk_queue).to receive(:pop_all)
          .ordered

        expect(bulk_queue).to receive(:add)
          .with(anything, another_serialized_document)
          .ordered

        subject.ingest(document)
        subject.ingest(another_document)
      end
    end
  end

  context '.delete' do
    context('when bulk queue still has capacity') do
      let(:id) { 15 }

      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.delete(id)
      end
    end

    context 'when bulk queue reports that it is full' do
      let(:delete_id) { 10 }
      let(:serialized_delete_op) { 'delete: 10' }
      let(:another_delete_id) { 11 }
      let(:another_serialized_delete_op) { 'delete: 11' }

      before(:each) do
        # emulated behaviour is:
        # Queue will be full once first item is added to it
        allow(bulk_queue).to receive(:will_fit?).and_return(true, false)
        allow(bulk_queue).to receive(:pop_all).and_return(serialized_delete_op)

        allow(serializer).to receive(:dump)
          .with({'delete' => hash_including('_id' => delete_id)})
          .and_return(serialized_delete_op)

        allow(serializer).to receive(:dump)
          .with({'delete' => hash_including('_id' => another_delete_id)})
          .and_return(another_serialized_delete_op)
      end

      it 'sends out one batch of changes' do
        expect(es_client).to receive(:bulk)
          .once
          .with(hash_including(:body => a_string_including(serialized_delete_op)))

        subject.delete(delete_id)
        subject.delete(another_delete_id)
      end

      it 'pops existing documents before adding a new one' do
        expect(bulk_queue).to receive(:add)
          .with(serialized_delete_op)
          .ordered

        expect(bulk_queue).to receive(:pop_all)
          .ordered

        expect(bulk_queue).to receive(:add)
          .with(another_serialized_delete_op)
          .ordered

        subject.delete(delete_id)
        subject.delete(another_delete_id)
      end
    end
  end

  context '.flush' do
    let(:operation) { 'bulk: delete something \n insert something else' } 

    before(:each) do
      allow(bulk_queue).to receive(:pop_all)
        .and_return(operation)
    end

    it 'sends data from bulk queue to elasticsearch' do
      expect(es_client).to receive(:bulk)
        .with(hash_including(:body => operation))

      subject.flush
    end
  end
end
