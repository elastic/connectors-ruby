#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'core/filtering'

describe Core::Filtering::PostProcessEngine do
  let(:job_description) do
    {
      Core::Filtering::FILTERING => [
          {
          Core::Filtering::DOMAIN => Core::Filtering::DEFAULT_DOMAIN,
          Core::Filtering::RULES => rules,
          Core::Filtering::ADVANCED_SNIPPET => snippet,
          Core::Filtering::WARNINGS => []
        }
      ]
    }
  end
  let(:rules) { [] }
  let(:snippet) { {} }
  let(:document) { {'foo' => 'bar'} }
  subject { described_class.new(job_description) }

  shared_examples_for 'included' do
    it 'is included' do
      expect(subject.process(document).is_include?).to be
    end
  end

  context 'empty rules' do
    it_behaves_like 'included'
  end


  context 'simple rule' do

    context 'no matches' do

    end

    context 'document with symbol keys' do

    end

    context 'document with nested field values' do

    end

    context 'document with int values' do

    end

    context 'document with date values' do

    end
  end

  context 'multiple rules' do

    context 'same field' do

    end

    context 'different field' do

    end

    context 'ordering' do

      context 'default rule in wrong spot' do

      end
    end
  end
end
