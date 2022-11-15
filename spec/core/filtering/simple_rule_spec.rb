#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true
require 'active_support/time'
require 'core/filtering/simple_rule'

describe Core::Filtering::SimpleRule do
  subject {
    Core::Filtering::SimpleRule.new(
      {
        Core::Filtering::SimpleRule::ID => id,
        Core::Filtering::SimpleRule::FIELD => field,
        Core::Filtering::SimpleRule::VALUE => value,
        Core::Filtering::SimpleRule::POLICY => policy,
        Core::Filtering::SimpleRule::RULE => rule
      }
    )
  }
  let(:id) { 'test' }
  let(:field) { 'str' }
  let(:value) { 'foo' }
  let(:policy) { Core::Filtering::SimpleRule::Policy::INCLUDE }
  let(:rule) { Core::Filtering::SimpleRule::Rule::EQUALS }
  let(:document) do
    {
      'str' => 'foo',
      'int' => 123,
      'time' => time_now,
      'datetime' => date_now,
      'bool' => false
    }
  end
  let(:date_now) { DateTime.now.new_offset(0) }
  let(:time_now) { Time.now }

  shared_examples_for 'a match' do
    it 'matches' do
      expect(subject.match?(document)).to be
    end
  end

  context 'default' do
    subject { Core::Filtering::SimpleRule::DEFAULT_RULE }
    let(:document) { {} }
    it_behaves_like 'a match'
  end
  context 'equals' do
    context 'date' do
      let(:field) { 'datetime' }
      let(:value) { date_now.to_s }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      let(:value) { 123 }
      it_behaves_like 'a match'
    end
    context 'str' do
      it_behaves_like 'a match'
    end
    context 'bool' do
      let(:field) { 'bool' }
      let(:value) { false }
      it_behaves_like 'a match'
    end
  end
  context 'regex' do
    let(:rule) { Core::Filtering::SimpleRule::Rule::REGEX }
    let(:value) { '.*' }
    context 'date' do
      let(:field) { 'datetime' }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      it_behaves_like 'a match'
    end
    context 'str' do
      it_behaves_like 'a match'
    end
    context 'bool' do
      let(:field) { 'bool' }
      it_behaves_like 'a match'
    end
  end
  context 'start_with' do
    let(:rule) { Core::Filtering::SimpleRule::Rule::STARTS_WITH }
    context 'date' do
      let(:field) { 'datetime' }
      let(:value) { date_now.year.to_s }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      let(:value) { '1' }
      it_behaves_like 'a match'
    end
    context 'str' do
      let(:value) { 'f' }
      it_behaves_like 'a match'
    end
    context 'bool' do
      let(:field) { 'bool' }
      let(:value) { 'f' }
      it_behaves_like 'a match'
    end
  end
  context 'ends_with' do
    let(:rule) { Core::Filtering::SimpleRule::Rule::ENDS_WITH }
    context 'date' do
      let(:field) { 'datetime' }
      let(:value) { '00:00' }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      let(:value) { '3' }
      it_behaves_like 'a match'
    end
    context 'str' do
      let(:value) { 'o' }
      it_behaves_like 'a match'
    end
    context 'bool' do
      let(:field) { 'bool' }
      let(:value) { 'alse' }
      it_behaves_like 'a match'
    end
  end
  context '<' do
    let(:rule) { Core::Filtering::SimpleRule::Rule::LESS_THAN }
    context 'date' do
      let(:field) { 'datetime' }
      let(:value) { (date_now + 1.day).to_s }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      let(:value) { '1111' }
      it_behaves_like 'a match'
    end
    context 'str' do
      let(:value) { 'goo' }
      it_behaves_like 'a match'
    end
    xcontext 'bool' do; end
  end
  context '>' do
    let(:rule) { Core::Filtering::SimpleRule::Rule::GREATER_THAN }
    context 'date' do
      let(:field) { 'datetime' }
      let(:value) { (date_now - 1.day).to_s }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      let(:value) { '44' }
      it_behaves_like 'a match'
    end
    context 'str' do
      let(:value) { 'ew' }
      it_behaves_like 'a match'
    end
    xcontext 'bool' do; end
  end
  context 'contains' do
    let(:rule) { Core::Filtering::SimpleRule::Rule::CONTAINS }
    context 'date' do
      let(:field) { 'datetime' }
      let(:value) { date_now.month.to_s }
      it_behaves_like 'a match'
    end
    context 'int' do
      let(:field) { 'int' }
      let(:value) { '2' }
      it_behaves_like 'a match'
    end
    context 'str' do
      let(:value) { 'o' }
      it_behaves_like 'a match'
    end
    context 'bool' do
      let(:field) { 'bool' }
      let(:value) { 'als' }
      it_behaves_like 'a match'
    end
  end

  context 'nil' do
    let(:field) { 'floopdoop' }
    it 'does not match' do
      expect(subject.match?(document)).to be_falsey
    end
  end
end
