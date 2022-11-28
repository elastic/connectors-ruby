#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core/filtering/advanced_snippet/advanced_snippet_validator'

describe Core::Filtering::AdvancedSnippet::AdvancedSnippetValidator do
  subject { described_class.new({}) }

  describe '#is_snippet_valid' do
    it 'should raise an exception' do
      expect { subject.is_snippet_valid }.to raise_exception
    end
  end
end
