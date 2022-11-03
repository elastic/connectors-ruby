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

  context 'when Elasticsearch::Client arguments are presented' do
    let(:disable_warnings) { false }

    before(:example) do
      # remove api_key to force Elasticsearch::Client pickup TLS options
      config[:elasticsearch].delete(:api_key)
    end

    context 'when transport_options is presented' do
      let(:transport_options) { { ssl: { verify: false } } }

      it 'configures Elasticsearch client with transport_options' do
        config[:elasticsearch][:transport_options] = transport_options
        expect(subject.transport.options[:transport_options][:ssl]).to eq(transport_options[:ssl])
      end
    end

    context 'when ca_fingerprint is presented' do
      let(:ca_fingerprint) { '64F2593F...' }

      it 'configures Elasticsearch client with ca_fingerprint' do
        config[:elasticsearch][:ca_fingerprint] = ca_fingerprint
        # there is no other way to get ca_fingerprint variable
        expect(subject.instance_variable_get(:@transport).instance_variable_get(:@ca_fingerprint)).to eq(ca_fingerprint)
      end
    end
  end
end
