require 'core/output_sink/es_sink'
require 'core/connector_settings'
require 'utility/es_client'

require 'spec_helper'

RSpec::Matchers.define :array_of_size do |x|
  match { |actual| actual.size == x }
end

describe Core::OutputSink::EsSink do
  subject { described_class.new(index_name, request_pipeline) }
  let(:index_name) { 'some-index-name' }
  let(:request_pipeline) { Core::ConnectorSettings::DEFAULT_REQUEST_PIPELINE }
  let(:es_client) { double }

  before(:each) do
    allow(Utility::EsClient).to receive(:new).and_return(es_client)
    allow(es_client).to receive(:bulk)
  end

  it_behaves_like 'implements all methods of base class' do
    let(:concrete_class_instance) { subject }
    let(:base_class_instance) { Core::OutputSink::BaseSink.new }
  end

  context '.ingest' do
    context('when flush threshold is not reached') do
      let(:doc) { { :id => 1, :something => :else } }

      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.ingest(doc)
      end
    end

    context 'when flush threshold is reached' do
      let(:flush_threshold) { 50 }
      let(:doc_count) { 55 }

      it 'sends out one batch of documents' do
        expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(flush_threshold), :pipeline => request_pipeline })

        (1..doc_count).each do |id|
          doc = { :id => id, :data => 'same data' }
          subject.ingest(doc)
        end
      end

      context 'when flush is called afterwards' do
        it 'second flush sends out the rest of the documents' do
          (1..doc_count).each do |id|
            doc = { :id => id, :data => 'same data' }
            subject.ingest(doc)
          end

          expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(doc_count - flush_threshold), :pipeline => request_pipeline })

          subject.flush
        end
      end
    end
  end

  context '.ingest_multiple' do
    context('when flush threshold is not reached') do
      let(:documents) { [{ :id => 1, :something => :else }, { :id => 2, :another => :one }] }

      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.ingest_multiple(documents)
      end
    end

    context 'when flush threshold is reached' do
      let(:flush_threshold) { 50 }
      let(:doc_count) { 55 }

      it 'sends out one batch of documents' do
        expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(flush_threshold), :pipeline => request_pipeline })

        documents = (1..doc_count).map do |id|
          { :id => id, :data => 'same data' }
        end

        subject.ingest_multiple(documents)
      end

      context 'when flush is called afterwards' do
        it 'second flush sends out the rest of the documents' do
          documents = (1..doc_count).map do |id|
            { :id => id, :data => 'same data' }
          end

          subject.ingest_multiple(documents)

          expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(doc_count - flush_threshold), :pipeline => request_pipeline })

          subject.flush
        end
      end
    end
  end

  context '.delete' do
    context('when flush threshold is not reached') do
      let(:id) { 15 }

      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.delete(id)
      end
    end

    context 'when flush threshold is reached' do
      let(:flush_threshold) { 50 }
      let(:doc_count) { 55 }

      it 'sends out one batch of changes' do
        expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(flush_threshold), :pipeline => request_pipeline })

        (1..doc_count).each do |id|
          subject.delete(id)
        end
      end

      context 'when flush is called afterwards' do
        it 'second flush sends out the rest of the documents' do
          (1..doc_count).each do |id|
            subject.delete(id)
          end

          expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(doc_count - flush_threshold), :pipeline => request_pipeline })

          subject.flush
        end
      end
    end
  end

  context '.delete_multiple' do
    context('when flush threshold is not reached') do
      let(:ids) { [15, 12, 11] }

      it 'does not immediately send the document into elasticsearch' do
        expect(es_client).to_not receive(:bulk)

        subject.delete_multiple(ids)
      end
    end

    context 'when flush threshold is reached' do
      let(:flush_threshold) { 50 }
      let(:doc_count) { 55 }

      it 'sends out one batch of documents' do
        expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(flush_threshold), :pipeline => request_pipeline })

        subject.delete_multiple((1..doc_count).to_a)
      end

      context 'when flush is called afterwards' do
        it 'second flush sends out the rest of the documents' do
          subject.delete_multiple((1..doc_count).to_a)

          expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(doc_count - flush_threshold), :pipeline => request_pipeline })

          subject.flush
        end
      end
    end
  end

  context '.flush' do
    let(:flush_threshold) { 50 }
    let(:doc_count) { 5 }

    it 'sends the documents once flush is triggered' do
      expect(es_client).to receive(:bulk).once.with({ :body => array_of_size(doc_count), :pipeline => request_pipeline })

      (1..doc_count).each do |id|
        doc = { :id => id, :data => 'same data' }
        subject.ingest(doc)
      end

      subject.flush
    end
  end
end
