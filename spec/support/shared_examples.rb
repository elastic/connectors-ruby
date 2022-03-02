#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

shared_examples 'does not populate updated_at' do
  it 'returns document that does not have updated_at field' do
    expect(document.with_indifferent_access).to_not include(have_key(:updated_at))
  end
end
