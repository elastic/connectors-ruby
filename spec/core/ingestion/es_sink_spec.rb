require 'core/ingestion/es_sink'
require 'utility/logger'
require 'core/connector_settings'
require 'utility/es_client'

require 'spec_helper'

RSpec::Matchers.define :array_of_size do |x|
  match { |actual| actual.size == x }
end

describe Core::Ingestion::EsSink do
  subject { described_class.new(index_name, request_pipeline, bulk_queue) }
  let(:index_name) { 'some-index-name' }
  let(:request_pipeline) { Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE }
  let(:es_client) { double }
  let(:bulk_queue) { double }
  let(:serializer) { double }

  let(:document) { { :id => 15 } }
  let(:serialized_document) { "id: #{document[:id]}, text: 'hoho, haha!'" }
  let(:deleted_id) { 25 }

  context 'when all private methods are implemented' do
    before(:each) do
      allow(Utility::EsClient).to receive(:new).and_return(es_client)

      allow(es_client).to receive(:bulk)

      # I attempted to test with this class mocked but it just made things much much harder
      allow(bulk_queue).to receive(:will_fit?).and_return(true)
      allow(bulk_queue).to receive(:add)
      allow(bulk_queue).to receive(:pop_all)

      allow(Elasticsearch::API).to receive(:serializer).and_return(serializer)
      allow(serializer).to receive(:dump).and_return('')
      allow(serializer).to receive(:dump).with(document).and_return(serialized_document)
    end

    context '#ingest' do
      context 'when ingested document is nil' do
        let(:document) { {} }

        it 'does not add document to the queue' do
          expect(bulk_queue).to_not receive(:add)

          subject.ingest(document)
        end

        it 'produces a warning' do
          expect(Utility::Logger).to receive(:warn)

          subject.ingest(document)
        end
      end

      context 'when ingested document is empty' do
        let(:document) { {} }

        it 'does not add document to the queue' do
          expect(bulk_queue).to_not receive(:add)

          subject.ingest(document)
        end

        it 'produces a warning' do
          expect(Utility::Logger).to receive(:warn)

          subject.ingest(document)
        end
      end

      context 'when ingested document is not empty' do
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
          let(:serialized_document) { "id: #{document[:id]}, text: 'hoho, haha!'" }
          let(:another_serialized_document) { "id: #{another_document[:id]}, text: 'work work!'" }

          before(:each) do
            # emulated behaviour is:
            # Queue will be full once first item is added to it
            allow(bulk_queue).to receive(:will_fit?).and_return(true, false)
            allow(bulk_queue).to receive(:pop_all).and_return([serialized_document])

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
    end

    context '#ingest_multiple' do
      let(:document1) {  { :id => 1 } }
      let(:document2) {  { :id => 2 } }
      let(:document3) {  { :id => 3 } }

      it 'calls ingest on each ingested document' do
        expect(subject).to receive(:ingest).with(document1)
        expect(subject).to receive(:ingest).with(document2)
        expect(subject).to receive(:ingest).with(document3)

        subject.ingest_multiple([document1, document2, document3])
      end
    end

    context '#delete' do
      context 'when id is not provided' do
        let(:deleted_id) { nil }

        it 'does not add operation to the queue' do
          expect(bulk_queue).to_not receive(:add)

          subject.delete(deleted_id)
        end
      end

      context 'when id is provided' do
        let(:deleted_id) { 'something-nice!' }

        it 'adds an operation to the queue' do
          expect(bulk_queue).to receive(:add)

          subject.delete(deleted_id)
        end

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
              .with({ 'delete' => hash_including('_id' => delete_id) })
              .and_return(serialized_delete_op)

            allow(serializer).to receive(:dump)
              .with({ 'delete' => hash_including('_id' => another_delete_id) })
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
    end

    context '#delete_multiple' do
      let(:id1) { 1 }
      let(:id2) { 2 }
      let(:id3) { 3 }

      it 'calls ingest on each ingested document' do
        expect(subject).to receive(:delete).with(id1)
        expect(subject).to receive(:delete).with(id2)
        expect(subject).to receive(:delete).with(id3)

        subject.delete_multiple([id1, id2, id3])
      end
    end

    context '#flush' do
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

    context '#ingestion_stats' do
      context 'when flush was not triggered' do
        before(:each) do
          15.times.each do |id|
            subject.ingest({ :id => id })
          end

          25.times.each do |id|
            subject.delete(id)
          end
        end

        it 'returns empty stats' do
          stats = subject.ingestion_stats

          expect(stats[:indexed_document_count]).to eq(0)
          expect(stats[:deleted_document_count]).to eq(0)
          expect(stats[:indexed_document_volume]).to eq(0)
        end
      end

      context 'when flush was triggered' do
        let(:operation) { 'bulk: delete something \n insert something else' }

        before(:each) do
          allow(bulk_queue).to receive(:pop_all)
            .and_return(operation)
        end

        context 'when nothing was ingested yet' do
          it 'returns empty stats' do
            stats = subject.ingestion_stats

            expect(stats[:indexed_document_count]).to eq(0)
            expect(stats[:deleted_document_count]).to eq(0)
            expect(stats[:indexed_document_volume]).to eq(0)
          end
        end

        context 'when some documents were ingested' do
          let(:document_count) { 5 }
          let(:serialized_object) { 'doesnt matter' }

          before(:each) do
            allow(serializer).to receive(:dump).and_return(serialized_object)

            document_count.times.each do |id|
              subject.ingest({ :id => id })
            end

            subject.flush
          end

          it 'returns expected indexed_document_count' do
            stats = subject.ingestion_stats

            expect(stats[:indexed_document_count]).to eq(document_count)
          end

          it 'returns expected indexed_document_volume' do
            stats = subject.ingestion_stats

            expect(stats[:indexed_document_volume]).to eq(document_count * serialized_object.bytesize)
          end
        end

        context 'when some documents were deleted' do
          let(:deleted_count) { 5 }

          before(:each) do
            deleted_count.times.each do |id|
              subject.delete(id)
            end

            subject.flush
          end

          it 'returns expected deleted_document_count' do
            stats = subject.ingestion_stats

            expect(stats[:deleted_document_count]).to eq(deleted_count)
          end
        end
      end
    end
  end
end
