require 'core/output_sink'

describe Core::OutputSink::BaseSink do
  subject { described_class.new }
  let(:document) { { :id => 15 } }
  let(:deleted_id) { 25 }

  it 'base_sink methods raise an error when called' do
    expect { subject.ingest(document) }.to raise_error(NotImplementedError)
    expect { subject.ingest_multiple([document]) }.to raise_error(NotImplementedError)
    expect { subject.delete(deleted_id) }.to raise_error(NotImplementedError)
    expect { subject.delete_multiple([deleted_id]) }.to raise_error(NotImplementedError)
    expect { subject.flush }.to raise_error(NotImplementedError)
  end

  context 'when all private methods are implemented' do
    before(:each) do
      allow(subject).to receive(:do_ingest)
      allow(subject).to receive(:do_delete)
      allow(subject).to receive(:do_flush)
      allow(subject).to receive(:do_serialize)
    end

    context '#ingest' do
      context 'when ingested document is empty' do
        let(:document) { {} }

        it 'does not call do_ingest' do
          expect(subject).to_not receive(:do_ingest)

          subject.ingest(document)
        end
      end

      context 'when ingested document is not empty' do
        let(:document_id) { 15 }
        let(:document) { { 'id' => document_id, 'something' => 'something' } }
        let(:serialized_document) { 'id: 15, something: something' }

        before(:each) do
          allow(subject).to receive(:do_serialize).with(document).and_return(serialized_document)
        end

        it 'calls do_ingest on serialized document' do
          expect(subject).to receive(:do_ingest).with(document_id, serialized_document)

          subject.ingest(document)
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

        it 'does not call do_delete' do
          expect(subject).to_not receive(:do_delete)

          subject.delete(deleted_id)
        end
      end

      context 'when id is provided' do
        let(:deleted_id) { 'something-nice!' }

        it 'calls do_delete with expected id' do
          expect(subject).to receive(:do_delete).with(deleted_id)

          subject.delete(deleted_id)
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
      it 'calls do_flush' do
        expect(subject).to receive(:do_flush)

        subject.flush
      end
    end

    context '#ingestion_stats' do
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
          allow(subject).to receive(:do_serialize).and_return(serialized_object)

          document_count.times.each do |id|
            subject.ingest({ :id => id })
          end
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
        end

        it 'returns expected deleted_document_count' do
          stats = subject.ingestion_stats

          expect(stats[:deleted_document_count]).to eq(deleted_count)
        end
      end
    end
  end
end
