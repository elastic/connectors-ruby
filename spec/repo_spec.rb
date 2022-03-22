#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

describe 'Repository' do
  let(:gemspecs) { Dir[File.join(__dir__, '../*.gemspec')].to_a }

  context 'NOTICE file' do
    let(:notice_file) { 'NOTICE.txt' }
    let(:notice_path) { File.join(__dir__, "../#{notice_file}") }
    it 'exists' do
      expect(File.exist?(notice_path)).to be(true)
    end

    it 'is included in our Gemspecs' do
      gemspecs.each do |gemspec|
        expect(File.read(gemspec)).to include(notice_file)
      end
    end
  end

  context 'LICENSE file' do
    let(:license_file) { 'LICENSE' }
    let(:license_path) { File.join(__dir__, "../#{license_file}") }
    it 'exists' do
      expect(File.exist?(license_path)).to be(true)
    end

    it 'is included in our Gemspecs' do
      gemspecs.each do |gemspec|
        expect(File.read(gemspec)).to include(license_file)
      end
    end
  end

  context 'License header' do
    let(:license_header) do
      %{#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#}
    end
    let(:code_files) { Dir['lib/{[!vendor/]**/*,*}.rb'] }

    it 'prefixes all code files' do
      code_files.each do |code_file|
        expect(File.read(code_file)).to start_with(license_header), "License header missing from #{code_file}"
      end
    end
  end
end
