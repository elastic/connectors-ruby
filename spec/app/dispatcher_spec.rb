#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'core'
require 'app/dispatcher'

describe App::Dispatcher do
  let(:scheduler) { double }
  let(:pool) { double }
  let(:job_runner) { double }
  let(:connector_id) { 123 }
  let(:info_message) { nil }

  before(:each) do
    allow(described_class).to receive(:scheduler).and_return(scheduler)
    allow(described_class).to receive(:pool).and_return(pool)

    allow(Core::ElasticConnectorActions).to receive(:ensure_content_index_exists)
    allow(pool).to receive(:post).and_yield
    allow(Core::SyncJobRunner).to receive(:new).and_return(job_runner)
    allow(Core::Heartbeat).to receive(:send)
    allow(job_runner).to receive(:execute)
    allow(Utility::ExceptionTracking).to receive(:log_exception)
    allow(Utility::Logger).to receive(:info)

    stub_const('App::Dispatcher::POLL_INTERVAL', 1)
    stub_const('App::Dispatcher::TERMINATION_TIMEOUT', 1)
    stub_const('App::Dispatcher::HEARTBEAT_INTERVAL', 60 * 30)
    stub_const('App::Dispatcher::MIN_THREADS', 0)
    stub_const('App::Dispatcher::MAX_THREADS', 5)
    stub_const('App::Dispatcher::MAX_QUEUE', 100)
  end

  after(:each) do
    described_class.instance_variable_set(:@running, Concurrent::AtomicBoolean.new(false))
  end

  describe '.start!' do
    context 'when it\'s called twice' do
      before(:each) do
        allow(described_class).to receive(:start_polling_jobs!)
        described_class.start!
      end

      it 'raises error' do
        expect { described_class.start! }.to raise_error
      end
    end

    context 'without native connectors' do
      before(:each) do
        allow(scheduler).to receive(:when_triggered)
      end
      it 'starts no sync jobs' do
        expect(described_class).to_not receive(:start_sync_task)
        expect(described_class).to_not receive(:start_heartbeat_task)
        expect(described_class).to_not receive(:start_configuration_task)
        described_class.start!
      end
    end

    context 'with native connectors' do
      let(:connector_settings) { double }

      before(:each) do
        allow(scheduler).to receive(:when_triggered).and_yield(connector_settings, task)
        allow(connector_settings).to receive(:formatted).and_return('')
      end

      shared_examples_for 'logs exception' do
        it 'logs exception' do
          expect(Utility::ExceptionTracking).to receive(:log_exception)
          expect { described_class.start! }.to_not raise_error
        end
      end
      shared_examples_for('logs info') do
        it 'does log info' do
          expect { described_class.start! }.to_not raise_error
          expect(Utility::Logger).to have_received(:info).with(Regexp.new(info_message, Regexp::IGNORECASE))
        end
      end

      context 'with invalid task' do
        let(:task) { :invalid }

        it 'logs error' do
          expect(Utility::Logger).to receive(:error)
          expect { described_class.start! }.to_not raise_error
        end
      end

      context 'with sync task' do
        let(:task) { :sync }

        before(:each) do
          allow(connector_settings).to receive(:service_type).and_return('')
          allow(connector_settings).to receive(:index_name).and_return('')
        end

        shared_examples_for 'sync' do
          it 'starts sync job' do
            expect(described_class).to receive(:start_heartbeat_task)
            expect(job_runner).to receive(:execute)
            expect { described_class.start! }.to_not raise_error
          end
        end

        shared_examples_for 'no sync' do
          it 'does not start sync job' do
            expect(described_class).to_not receive(:start_heartbeat_task)
            expect(job_runner).to_not receive(:execute)
            expect { described_class.start! }.to_not raise_error
          end
        end

        shared_examples_for 'interrupt' do
          it 'shuts down sync jobs' do
            expect(described_class).to receive(:shutdown_sync_jobs_with_error)
            expect { described_class.start! }.to_not raise_error
          end
        end

        it_behaves_like 'sync'

        context 'when sync throws an error' do
          before(:each) do
            allow(job_runner).to receive(:execute).and_raise('Oh no!')
          end

          it_behaves_like 'logs exception'
        end

        context 'when app exits unexpectedly' do
          context 'one sync job runs' do
            let(:task) { :sync }

            before(:each) do
              allow(connector_settings).to receive(:service_type).and_return('')
              allow(connector_settings).to receive(:index_name).and_return('')
              allow(job_runner).to receive(:execute).and_raise(Interrupt)
            end

            it_behaves_like 'interrupt'
          end

        end

        context 'when sync is already running' do
          before(:each) do
            allow(job_runner).to receive(:execute).and_raise(Core::JobAlreadyRunningError.new(connector_id))
          end
          let(:info_message) { 'already running' }

          it_behaves_like 'logs info'
        end

        context 'on version conflict' do
          before(:each) do
            allow(job_runner).to receive(:execute).and_raise(Core::ConnectorVersionChangedError.new(connector_id, 0, 0))
          end
          let(:info_message) { 'version conflict' }

          it_behaves_like 'logs info'
        end
      end

      context 'with heartbeat task' do
        let(:task) { :heartbeat }

        it 'should send heartbeat' do
          expect(Core::Heartbeat).to receive(:send)
          expect { described_class.start! }.to_not raise_error
        end

        context 'when heartbeat throws an error' do
          before(:each) do
            allow(Core::Heartbeat).to receive(:send).and_raise('Oh no!')
          end

          it_behaves_like 'logs exception'
        end
      end

      context 'with configuration task' do
        let(:task) { :configuration }
        let(:native_mode) { true }
        let(:needs_service_type) { false }
        let(:service_type) { 'custom' }

        before(:each) do
          allow(connector_settings).to receive(:needs_service_type?).and_return(needs_service_type)
          allow(App::Config).to receive(:native_mode).and_return(native_mode)
          allow(App::Config).to receive(:service_type).and_return(service_type)
        end

        it 'should update configuration without service type' do
          expect(Core::Configuration).to receive(:update).with(connector_settings, nil)
          expect { described_class.start! }.to_not raise_error
        end

        context 'in non-native mode' do
          let(:native_mode) { false }
          let(:needs_service_type) { true }

          it 'should update configuration with service type' do
            expect(Core::Configuration).to receive(:update).with(connector_settings, service_type)
            expect { described_class.start! }.to_not raise_error
          end
        end

        context 'when configuration throws an error' do
          before(:each) do
            allow(Core::Configuration).to receive(:update).and_raise('Oh no!')
          end

          it_behaves_like 'logs exception'
        end
      end
    end
  end

  describe '.shutdown!' do
    before(:each) do
      allow(described_class).to receive(:start_polling_jobs!)
      described_class.start!
    end

    it 'shuts down correctly' do
      expect(scheduler).to receive(:shutdown)
      expect(pool).to receive(:shutdown)
      expect(pool).to receive(:wait_for_termination)
      expect(described_class).to receive(:shutdown_sync_jobs_with_error)
      described_class.shutdown!
    end
  end
end
