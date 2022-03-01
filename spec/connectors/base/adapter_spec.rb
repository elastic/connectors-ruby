#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/adapter'

describe Connectors::Base::Adapter do
  context '.generate_id_helpers' do
    before do
      class Dummy < described_class
        generate_id_helpers :dummy, 'dummy'
      end
    end

    context 'inherited class methods based on class name' do
      it 'should convert id to fp id' do
        expect(Dummy.dummy_id_to_fp_id('1')).to eq('dummy_1')
      end

      it 'should convert an fp id to a dummy id' do
        expect(Dummy.fp_id_to_dummy_id('dummy_1')).to eq('1')
      end

      it 'should have predicate method' do
        expect(Dummy.fp_id_is_dummy_id?('dummy_1')).to eq(true)
      end
    end

    it 'should throw an error if the fp id is invalid' do
      expect { Dummy.fp_id_to_dummy_id('invalid_id') }.to raise_error(ArgumentError)
    end

    it 'should throw an error if the fp id does not match the expected format' do
      expect { Dummy.fp_id_to_dummy_id('dummy_') }.to raise_error(ArgumentError)
    end
  end

  describe '.extension_for_file' do
    it 'should downcase the extension' do
      expect(described_class.extension_for_file('asdf.PNG')).to eq('png')
    end

    it 'should not blow up for an input that does not have a file extension' do
      expect(described_class.extension_for_file('nofileextension')).to be_nil
    end
  end

  describe '.url_to_path' do
    [
      [nil, nil],
      ['', nil],
      [' ', nil],
      ["\t", nil],
      ['http//www.example.com/path/more_path', nil],
      ['//www.example.com/path/more_path', nil],
      ['www.example.com/path/more_path', nil],
      ['example.com/path/more_path', nil],
      ['http://www.example.com', nil],
      ['http://www.example.com/', '/'],
      ['http://www.example.com/path/more_path', '/path/more_path'],
      ['http://www.example.com:1234/path/more_path', '/path/more_path'],
      ['http://www.example.com/path/more_path?query=param', '/path/more_path'],
      ['http://www.example.com/path/more_path?query=param&more=params', '/path/more_path'],
      ['http://www.example.com/path/more_path#fragment', '/path/more_path'],
    ].each do |input, output|
      it "converts [#{input.nil? ? '(nil)' : input}] to [#{output.nil? ? '(nil)' : output}]" do
        expect(described_class.url_to_path(input)).to eql(output)
      end
    end
  end

  describe 'swiftype_document_from_configured_object_base' do
    let(:object_type) { 'animal' }
    let(:field_remote) { 'RemoteFieldName' }
    let(:field_target) { 'target_field_name' }
    let(:field_value) { 'a value' }
    let(:nested_field_remote) { 'NestedRemoteField.Name' }
    let(:nested_field_target) { 'nested_target_field_name' }
    let(:nested_field_value) { 'a nested_value' }
    let(:missing_field_remote) { 'MissingFieldRemote' }
    let(:missing_field_target) { 'MissingFieldTarget' }
    let(:object) do
      Hashie::Mash.new({
                         field_remote.to_sym => field_value,
                         :NestedRemoteField => {
                           :Name => nested_field_value
                         }
                       })
    end
    let(:fields) do
      [
        {
          :remote => field_remote,
          :target => field_target
        },
        {
          :remote => nested_field_remote,
          :target => nested_field_target
        },
        {
          :remote => missing_field_remote,
          :target => missing_field_target
        }
      ]
    end

    subject { described_class.swiftype_document_from_configured_object_base(:object_type => object_type, :object => object, :fields => fields) }

    it 'sets the object type' do
      expect(subject).to match(hash_including(:type => 'animal'))
    end

    it 'maps a field' do
      expect(subject).to match(hash_including(field_target.to_sym => field_value))
    end

    it 'can handle basic nested fields with dot notation' do
      expect(subject).to match(hash_including(nested_field_target.to_sym => nested_field_value))
    end

    it 'does not include a missing field' do
      expect(subject).not_to have_key(missing_field_target)
    end
  end
end
