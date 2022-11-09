require 'core/output_sink'
require 'utility/logger'

describe Core::OutputSink::Sink do
  subject { described_class.new(sink_strategy) }
  let(:sink_strategy) { double }
  let(:document) { { :id => 15 } }
  let(:deleted_id) { 25 }

  context 'when all private methods are implemented' do
    before(:each) do
      allow(sink_strategy).to receive(:ingest)
      allow(sink_strategy).to receive(:delete)
      allow(sink_strategy).to receive(:flush)
      allow(sink_strategy).to receive(:serialize)
    end

    context '#ingest' do
      context 'when ingested document is nil' do
        let(:document) { {} }

        it 'does not call ingest for strategy' do
          expect(sink_strategy).to_not receive(:ingest)

          subject.ingest(document)
        end

        it 'produces a warning' do
          expect(Utility::Logger).to receive(:warn)

          subject.ingest(document)
        end
      end

      context 'when ingested document is empty' do
        let(:document) { {} }

        it 'does not call ingest for strategy' do
          expect(sink_strategy).to_not receive(:ingest)

          subject.ingest(document)
        end

        it 'produces a warning' do
          expect(Utility::Logger).to receive(:warn)

          subject.ingest(document)
        end
      end

      context 'when ingested document is not empty' do
        let(:document_id) { 15 }
        let(:document) { { 'id' => document_id, 'something' => 'something' } }
        let(:serialized_document) { 'id: 15, something: something' }

        before(:each) do
          allow(sink_strategy).to receive(:serialize).with(document).and_return(serialized_document)
        end

        it 'calls strategy ingest on serialized document' do
          expect(sink_strategy).to receive(:ingest).with(document_id, serialized_document)

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

        it 'does not call delete for strategy' do
          expect(sink_strategy).to_not receive(:delete)

          subject.delete(deleted_id)
        end
      end

      context 'when id is provided' do
        let(:deleted_id) { 'something-nice!' }

        it 'calls delete for strategy with expected id' do
          expect(sink_strategy).to receive(:delete).with(deleted_id)

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
      it 'calls flush for strategy' do
        expect(sink_strategy).to receive(:flush)

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
          allow(sink_strategy).to receive(:serialize).and_return(serialized_object)

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
