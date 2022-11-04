#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility/common'

RSpec.describe Utility::Common do
  context '.return_if_present' do
    context 'no argument is present' do
      it 'returns nil' do
        expect(Utility::Common.return_if_present).to be_nil
      end
    end

    context 'one non-nil argument is present' do
      it 'returns the non-nil argument' do
        expect(Utility::Common.return_if_present('one')).to eq('one')
      end
    end

    context 'first argument is nil and second is present' do
      it 'returns the second argument' do
        expect(Utility::Common.return_if_present(nil, 'second')).to eq('second')
      end
    end

    context 'first and second argument are present' do
      it 'returns the first argument' do
        expect(Utility::Common.return_if_present('first', 'second')).to eq('first')
      end
    end
  end
end
