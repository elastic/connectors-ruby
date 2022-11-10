#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

describe Core::Filtering::SimpleRule do


  context 'default' do; end
  context 'equals' do; end
  context 'regex' do; end
  context 'start_with' do; end
  context 'ends_with' do; end
  context '<' do
    context 'date' do; end
    context 'int' do; end
    context 'str' do; end
    context 'bool' do; end
  end

  context '>' do
    context 'date' do; end
    context 'int' do; end
    context 'str' do; end
    context 'bool' do; end
  end
  context 'contains' do; end
  context 'coercion' do; end
end
