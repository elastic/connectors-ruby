#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/tolerable_error_helper'

describe Connectors::TolerableErrorHelper do
  let(:error_monitor) { double }
  subject { described_class.new(error_monitor) }

  before(:each) do
    allow(Utility::Logger).to receive(:debug)
    allow(Utility::Logger).to receive(:error)
    allow(Utility::Logger).to receive(:warn)

    allow(error_monitor).to receive(:note_success)
    allow(error_monitor).to receive(:note_error)
  end

  describe '#yield_single_document' do
    context 'when no errors happen' do
      it 'notes success to error monitor' do
        expect(error_monitor).to receive(:note_success)

        subject.yield_single_document(identifier: 'hello!') do
          { :bring => 'a_towel' }
        end
      end
    end

    context 'when an error happens' do
      let(:error) { StandardError.new }
      let(:unique_error_id) { 'hey im an error' }

      before(:each) do
        allow(Utility::ExceptionTracking).to receive(:augment_exception).with(error) # this method actually populates id of the error
        allow(error).to receive(:id).and_return(unique_error_id)
      end

      it 'augments the error' do
        expect(Utility::ExceptionTracking).to receive(:augment_exception).with(error)

        subject.yield_single_document(identifier: 'hello!') do
          raise error
        end
      end

      it 'notes failure to error monitor' do
        expect(error_monitor).to receive(:note_error).with(error, { :id => unique_error_id })

        subject.yield_single_document(identifier: 'hello!') do
          raise error
        end
      end
    end
  end
end
