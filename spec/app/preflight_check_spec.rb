#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#
# frozen_string_literal: true

require 'app/preflight_check'

describe App::PreflightCheck do
  describe '.run!' do
    let(:client) { double }

    before(:each) do
      allow(described_class).to receive(:client).and_return(client)
    end

    context 'when Elasticsearch is not running' do
      let(:cluster) { double }

      it 'should retry multiple times and fail the check' do
        stub_const('App::PreflightCheck::STARTUP_RETRY_INTERVAL', 1)
        stub_const('App::PreflightCheck::STARTUP_RETRY_TIMEOUT', 3)
        allow(client).to receive(:cluster).and_return(cluster)
        expect(cluster).to receive(:health).at_least(2).times.and_raise(Faraday::ConnectionFailed)
        described_class.run!
      end
    end

    context 'when Elasticsearch is running' do
      before(:each) do
        stub_const('App::PreflightCheck::STARTUP_RETRY_INTERVAL', 0)
        stub_const('App::PreflightCheck::STARTUP_RETRY_TIMEOUT', 0)
        allow(client).to receive_message_chain(:cluster, :health).and_return({ 'status' => status })
      end

      context 'when Elasticsearch status is red' do
        let(:status) { 'red' }
        it 'should fail the check' do
          expect { described_class.run! }.to raise_error(described_class::CheckFailure)
        end
      end

      context 'when Elasticsearch status is yellow' do
        let(:status) { 'yellow' }
        before(:each) do
          allow(described_class).to receive(:check_es_version!)
          allow(described_class).to receive(:check_system_indices!)
        end

        it 'should log warn message' do
          expect(Utility::Logger).to receive(:warn)
          described_class.run!
        end
      end

      context 'when Elasticsearch status is invalid status' do
        let(:status) { 'garbage' }

        it 'should fail the check' do
          expect { described_class.run! }.to raise_error(described_class::CheckFailure)
        end
      end

      context 'when Elasticsearch status is green' do
        let(:status) { 'green' }
        let(:es_version) { '8.4.0-SNAPSHOT' }
        before(:each) do
          allow(client).to receive(:info).and_return({ 'version' => { 'number' => es_version } })
        end

        context 'when Elasticsearch version doesn\'t match connector service version' do
          it 'should fail the check' do
            stub_const('App::VERSION', '8.5.0.0-foobar')
            expect { described_class.run! }.to raise_error(described_class::CheckFailure)
          end
        end

        context 'when Elasticsearch version matches connector service version' do
          before(:each) do
            stub_const('App::VERSION', '8.4.0.0-foobar')
            allow(client).to receive_message_chain(:indices, :exists?).with(:index => Utility::Constants::CONNECTORS_INDEX).and_return(connector_index_exist)
            allow(client).to receive_message_chain(:indices, :exists?).with(:index => Utility::Constants::JOB_INDEX).and_return(job_index_exist)
          end

          context 'when both indices exist' do
            let(:connector_index_exist) { true }
            let(:job_index_exist) { true }

            it 'should pass the check' do
              expect { described_class.run! }.to_not raise_error(described_class::CheckFailure)
            end
          end

          context 'when connector index does not exist' do
            let(:connector_index_exist) { false }
            let(:job_index_exist) { true }

            it 'should fail the check' do
              expect { described_class.run! }.to raise_error(described_class::CheckFailure)
            end
          end

          context 'when job index does not exist' do
            let(:connector_index_exist) { true }
            let(:job_index_exist) { false }

            it 'should fail the check' do
              expect { described_class.run! }.to raise_error(described_class::CheckFailure)
            end
          end

          context 'when both indices do not exist' do
            let(:connector_index_exist) { false }
            let(:job_index_exist) { false }

            it 'should fail the check' do
              expect { described_class.run! }.to raise_error(described_class::CheckFailure)
            end
          end
        end
      end
    end
  end
end
