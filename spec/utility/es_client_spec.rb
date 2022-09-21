require 'elasticsearch'
require 'utility/es_client'
require 'utility/environment'

RSpec.describe Utility::EsClient do
  let(:host) { 'http://notreallyaserver' }
  let(:config) do
    {
      :service_type => 'example',
      :log_level => 'INFO',
      :connector_id => '1',
      :elasticsearch => {
        :api_key => 'key',
        :hosts => host,
        :disable_warnings => disable_warnings
      }
    }
  end

  let(:subject) { described_class.new(config[:elasticsearch]) }

  before(:each) do
    stub_request(:get, "#{host}:9200/")
      .to_return(status: 403, body: '', headers: {})
    stub_request(:get, "#{host}:9200/_cluster/health")
  end

  context 'when wrapped in Utility::Environment.set_execution_environment' do
    around(:each) do |example|
      Utility::Environment.set_execution_environment(config) do
        example.run
      end
    end

    context 'when disable_warnings=false' do
      let(:disable_warnings) { false }
      it 'receives warnings from elasticsearch client' do
        expect {
          subject.cluster.health
        }.to output(/#{Elasticsearch::SECURITY_PRIVILEGES_VALIDATION_WARNING}/).to_stderr
      end
    end

    context 'when disable_warnings=true' do
      let(:disable_warnings) { true }
      it 'receives no warnings from elasticsearch client' do
        expect {
          subject.cluster.health
        }.to_not output.to_stderr
      end
    end
  end
end
