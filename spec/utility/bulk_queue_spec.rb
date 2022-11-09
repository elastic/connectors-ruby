#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'utility/bulk_queue'

describe Utility::BulkQueue do
  let(:subject) { described_class.new(count_threshold, size_threshold) }
  let(:count_threshold) { 50 }
  let(:size_threshold) { 999999999 } # super high default

  context '.add' do
    before(:each) do
      allow(subject).to receive(:will_fit?)
        .and_return(true)
    end

    context 'when new element won\'t fit any more' do
      before(:each) do
        allow(subject).to receive(:will_fit?)
          .and_return(false)
      end

      it 'raises an error' do
        expect { subject.add('some-op') }.to raise_error(Utility::BulkQueue::QueueOverflowError)
      end
    end

    context 'when only operation is added' do
      let(:op) { 'do: something' }

      it 'adds only the operation to the buffer' do
        subject.add(op)

        expect(subject.pop_all).to include(op)
      end
    end

    context 'when operation with payload is added' do
      let(:op) { 'index: id=12' }
      let(:payload) { 'text: something, counter: 15' }

      it 'adds both operation and payload to the buffer' do
        subject.add(op, payload)

        buffer = subject.pop_all

        expect(buffer).to include(op)
        expect(buffer).to include(payload)
      end
    end
  end

  context '.will_fit?' do
    let(:op) { 'hello: world' }

    context 'when thresholds are not reached' do
      it 'returns true' do
        expect(subject.will_fit?(op)).to eq(true)
      end
    end

    context 'when too many items were added to the queue' do
      let(:count_threshold) { 10 }

      before(:each) do
        4.times.each do |i|
          subject.add("op: #{i}")
        end

        6.times.each do |i|
          subject.add("op-w-payload: #{i}, payload: #{i}")
        end
      end

      it 'returns false' do
        expect(subject.will_fit?(op)).to eq(false)
      end
    end

    context 'when size of items added to the queue is too big' do
      let(:big_operation) { 'this_is: a big operation' }
      let(:big_operation_bytesize) { 300 }
      let(:size_threshold) { big_operation_bytesize * 5 - 1 } # only 4 big operations will fit

      before(:each) do
        allow(big_operation).to receive(:bytesize).and_return(big_operation_bytesize)

        4.times do
          subject.add(big_operation)
        end
      end

      it 'returns false' do
        expect(subject.will_fit?(big_operation)).to eq(false)
      end
    end
  end

  context '.pop_all' do
    context 'when queue is empty' do
      it 'returns empty string' do
        expect(subject.pop_all).to eq('')
      end
    end

    context 'when some operations were added to the queue' do
      before(:each) do
        25.times do |i|
          subject.add("some_op: #{i}")
        end
      end

      it 'cleans up the queue' do
        subject.pop_all

        expect(subject.pop_all).to eq('')
      end
    end
  end

  context '.current_stats' do
    let(:op_count) { 15 }
    let(:big_operation) { 'this_is: a big operation' }
    let(:big_operation_bytesize) { 300 }

    before(:each) do
      allow(big_operation).to receive(:bytesize).and_return(big_operation_bytesize)

      op_count.times do
        subject.add(big_operation)
      end
    end

    it 'returns expected number of operations' do
      expect(subject.current_stats[:current_operation_count]).to eq(op_count)
    end

    it 'returns expected size of operations' do
      expect(subject.current_stats[:current_buffer_size]).to eq(op_count * big_operation_bytesize)
    end

    context 'when queue is popped' do
      before(:each) do
        subject.pop_all
      end

      it 'returns expected number of operations' do
        expect(subject.current_stats[:current_operation_count]).to eq(0)
      end

      it 'returns expected size of operations' do
        expect(subject.current_stats[:current_buffer_size]).to eq(0)
      end
    end
  end
end
