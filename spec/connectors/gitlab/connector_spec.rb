# frozen_string_literal: true

require 'connectors/gitlab/connector'
require 'connectors/gitlab/custom_client'
require 'core/filtering/validation_status'
require 'spec_helper'

describe Connectors::GitLab::Connector do
  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:base_url) { Connectors::GitLab::DEFAULT_BASE_URL }
  let(:config) do
    {
      :base_url => { :value => base_url },
      :api_key => { :value => 'some_token' }
    }
  end

  let(:advanced_config) {
    {}
  }

  let(:filtering) {
    {
      :advanced_config => advanced_config
    }
  }

  subject do
    Connectors::GitLab::Connector.new(configuration: config)
  end

  it_behaves_like 'a connector'

  context '#validate_filtering' do
    shared_examples_for 'filtering is valid' do
      it 'returns validation result with state \'valid\' and no errors' do
        validation_result = described_class.validate_filtering(filtering)

        expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::VALID)
        expect(validation_result[:errors]).to be_empty
      end
    end

    shared_examples_for 'filtering is invalid' do
      it 'returns validation result with state \'invalid\' and no errors' do
        validation_result = described_class.validate_filtering(filtering)

        expect(validation_result[:state]).to eq(Core::Filtering::ValidationStatus::INVALID)
        expect(validation_result[:errors]).to_not be_empty
      end
    end

    context 'filtering is not present' do
      let(:filtering) {
        {}
      }

      it_behaves_like 'filtering is valid'
    end

    context 'filtering is present' do
      let(:filtering) {
        {
          :advanced_config => advanced_config
        }
      }

      # TODO: will be replaced with GitLab specific filtering validation
      it_behaves_like 'filtering is invalid'
    end
  end

  context '#is_healthy?' do
    it 'correctly returns true on 200' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 200, :body => user_json)
      result = subject.is_healthy?

      expect(result).to eq(true)
    end

    it 'correctly returns false on 401' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.is_healthy?

      expect(result).to eq(false)
    end

    it 'correctly returns false on 400' do
      stub_request(:get, "#{base_url}/user")
        .to_return(:status => 401, :body => '{ "error": "wrong token" }')
      result = subject.is_healthy?

      expect(result).to eq(false)
    end
  end

  context '#yield_documents' do
    let(:page_count) { 3 }
    let(:page_size) { 100 }

    let(:first_page_next_page_link) { 'https://next.page/1' }
    let(:second_page_next_page_link) { 'https://next.page/2' }
    let(:third_page_next_page_link) { 'https://next.page/3' }

    let(:extractor) { double }

    def create_data_page(ids)
      ids.map do |id|
        {
          :id => id,
          :something => "something-#{id}"
        }
      end
    end

    before(:each) do
      allow(Connectors::GitLab::Extractor).to receive(:new).and_return(extractor)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(nil)
        .and_yield(create_data_page(1..page_size))
        .and_return(first_page_next_page_link)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(first_page_next_page_link)
        .and_yield(create_data_page(page_size + 1..page_size * 2))
        .and_return(second_page_next_page_link)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(second_page_next_page_link)
        .and_yield(create_data_page(page_size * 2 + 1..page_size * 3))
        .and_return(third_page_next_page_link)

      allow(extractor)
        .to receive(:yield_projects_page)
        .with(third_page_next_page_link)
        .and_return(nil)
    end

    it 'extracts all documents' do
      docs = []

      subject.yield_documents { |doc| docs << doc }

      expect(docs.size).to eq(page_count * page_size)
    end
  end
end
