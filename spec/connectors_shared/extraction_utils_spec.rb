#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'benchmark'
require 'nokogiri'

require 'utility/extraction_utils'

describe Utility::ExtractionUtils do
  describe '.node_descendant_text' do
    it 'should raise an error unless given a node object' do
      expect { described_class.node_descendant_text('something') }.to raise_error(ArgumentError, /node-like/)
    end

    it 'should replace break tags with spaces' do
      node = Nokogiri::HTML('<body>Hello,<br>World!')
      expect(described_class.node_descendant_text(node)).to eq('Hello, World!')
    end

    context 'with uncrate.com pages' do
      let(:content) { File.read(File.join(File.join(__dir__, '..', 'fixtures'), 'uncrate.com.html')) }
      let(:html) { Nokogiri::HTML(content) }

      it 'should have a reasonable performance' do
        duration = Benchmark.measure do
          described_class.node_descendant_text(html)
        end

        # It usually takes ~250 msec, used to take 180 sec before we fixed it, so let's aim for something reasonable
        expect(duration.real).to be < 5
      end
    end
  end
end
