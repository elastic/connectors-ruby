require 'core/connector_settings'
require 'connectors/crawler/scheduler'
require 'core/elastic_connector_actions'
require 'active_support/core_ext/numeric/time'
require 'timecop'

describe Connectors::Crawler::Scheduler do
  subject { described_class.new(poll_interval) }

  let(:connector_id1) { '123' }
  let(:connector_id2) { '456' }
  let(:poll_interval) { 999 }

  let(:crawler1) { { :_id => connector_id1 } }
  let(:crawler2) { { :_id => connector_id2 } }

  let(:globals) { {} }

  let(:connector_settings1) { Core::ConnectorSettings.new(crawler1, globals) }
  let(:connector_settings2) { Core::ConnectorSettings.new(crawler2, globals) }

  let(:last_synced) { Time.now - 1.day }
  let(:sync_now) { false }
  let(:connector_status) { 'SOME NICE STATUS' }
  let(:scheduling_enabled) { true }
  let(:scheduling_interval) { '0 * * * * *' }
  let(:scheduling_settings) { { :enabled => scheduling_enabled, :interval => scheduling_interval } }
  let(:crawlers_settings) do
    [connector_settings1, connector_settings2]
  end

  before(:each) do
    allow(Core::ElasticConnectorActions).to receive(:connectors_meta).and_return({})
    allow(Core::ConnectorSettings).to receive(:fetch).with(connector_id1).and_return(connector_settings1)
    allow(Core::ConnectorSettings).to receive(:fetch).with(connector_id2).and_return(connector_settings2)

    [connector_settings1, connector_settings2].each { |settings|
      allow(settings).to receive(:connector_status).and_return(connector_status)
      allow(settings).to receive(:connector_status_allows_sync?).and_return(true)
      allow(settings).to receive(:[]).with(:last_synced).and_return(last_synced.to_s)
      allow(settings).to receive(:[]).with(:sync_now).and_return(sync_now)
      allow(settings).to receive(:[]).with(:status).and_return(connector_status)
      allow(settings).to receive(:scheduling_settings).and_return(scheduling_settings)
    }

    allow(Core::ElasticConnectorActions).to receive(:crawler_connectors).and_return(crawlers_settings)

    # Also we don't really wanna sleep
    allow_any_instance_of(Object).to receive(:sleep)

    # Scheduler will never stop, it's an infinite loop, thus to test it in a simpler way we trigger loop only 1 time here
    subject.instance_variable_set(:@is_shutting_down, true) # prevent infinite loop - run just one cycle
  end

  shared_examples_for 'sync triggers' do
    it '' do
      expect { |b| subject.when_triggered(&b) }.to yield_successive_args(*crawlers_settings)
    end
  end

  shared_examples_for 'sync does not trigger' do
    it '' do
      expect { |b| subject.when_triggered(&b) }.to_not yield_successive_args(anything)
    end
  end

  describe '.when_triggered' do
    context 'when no native connectors found' do
      let(:crawler_connectors) { [] }
      it_behaves_like 'sync does not trigger'
    end

    context 'when two native connectors found' do
      it_behaves_like 'sync triggers'
    end

    context 'when one native connectors found' do
      let(:crawler_connectors) { [{ :id => connector_id1, :service_type => 'example' }] }
      let(:crawlers_settings) { [connector_settings1] }
      it_behaves_like 'sync triggers'
    end
  end
end
