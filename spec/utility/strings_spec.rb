#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'utility'

RSpec.describe Utility::Strings do
  context '.format_string_array' do
    context 'called with nil' do
      it 'returns default string' do
        expect(Utility::Strings.format_string_array(nil, default: ' ')).to eq(' ')
      end
    end

    context 'called with an empty array' do
      it 'returns default string' do
        expect(Utility::Strings.format_string_array([], default: ' ')).to eq(' ')
      end
    end

    context 'called with one element array' do
      context 'with default delimiter' do
        it 'returns formatted one element string with single quote delimiter (default)' do
          expect(Utility::Strings.format_string_array(['word'])).to eq('\'word\'')
        end
      end

      context 'with custom double quote delimiter' do
        it 'returns formatted one element string with double quotes delimiter' do
          expect(Utility::Strings.format_string_array(['word'], delimiter: '"')).to eq('"word"')
        end
      end
    end

    context 'called with three elements array' do
      it 'returns formatted three elements string' do
        expect(Utility::Strings.format_string_array(%w[one two three], separator: ', ')).to eq('\'one\', \'two\', \'three\'')
      end

      it 'returns formatted three elements string with custom delimiter and custom separator' do
        expect(Utility::Strings.format_string_array(%w[one two three], separator: '|', delimiter: '"')).to eq('"one"|"two"|"three"')
      end
    end
  end
end
