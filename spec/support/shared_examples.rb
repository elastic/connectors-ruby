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

    expect(specific_class_public_methods).to include(*base_class_public_methods)
  end
end

shared_examples 'does not populate updated_at' do
  it 'returns document that does not have updated_at field' do
    expect(document.with_indifferent_access).to_not include(have_key(:updated_at))
  end
end

shared_examples 'a connector' do
  it 'implements display_name class method' do
    expect(described_class.display_name).to_not be_nil
  end

  it 'implements service_type class method' do
    expect(described_class.service_type).to_not be_nil
  end

  it 'implements configurable_fields class method' do
    expect(described_class.configurable_fields).to_not be_nil
  end

  it 'configurable_fields class method returns valid configuration' do
    # expected configurable fields format:
    # {
    #   'key' => {
    #     'label' => '',
    #     'value' => ''
    #   }
    # }
    configurable_fields = described_class.configurable_fields.with_indifferent_access

    expect(configurable_fields).to respond_to(:keys)
    expect(configurable_fields).to respond_to(:[])

    configurable_fields.each_key do |field_name|
      field_definition = configurable_fields[field_name]

      # is a hash too
      expect(field_definition).to respond_to(:keys)
      expect(field_definition).to respond_to(:[])

      expect(field_definition['label']).to_not be_nil
      if field_definition['value']
        expect(field_definition['value']).to_not be_nil
      end
    end
  end
end
