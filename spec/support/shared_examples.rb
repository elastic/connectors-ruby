#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

shared_examples 'implements all methods of base class' do
  it '' do
    base_class_public_methods = get_class_specific_public_methods(base_class_instance)
    specific_class_public_methods = get_class_specific_public_methods(concrete_class_instance)

    expect(specific_class_public_methods).to eq(base_class_public_methods)
  end
end

shared_examples 'does not populate updated_at' do
  it 'returns document that does not have updated_at field' do
    expect(document.with_indifferent_access).to_not include(have_key(:updated_at))
  end
end
