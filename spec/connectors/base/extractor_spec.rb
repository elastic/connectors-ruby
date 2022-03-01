#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors/base/config'
require 'connectors/base/extractor'

describe Connectors::Base::Extractor do
  let(:service_type) { 'sharepoint' }
  let(:config) { Connectors::Base::Config.new(:cursors => {}) }
  let(:content_source_id) { BSON::ObjectId.new }
  let(:cursors) { nil }
  let(:client_proc) { proc { Connectors::Base::CustomClient.new(base_url: 'https://example.com') } }
  let(:authorization_data_proc) { proc { {} } }

  subject do
    described_class.new(
      :content_source_id => content_source_id,
      :service_type => service_type,
      :config => Connectors::Base::Config.new(:cursors => cursors),
      :features => [],
      :client_proc => client_proc,
      :authorization_data_proc => authorization_data_proc
    )
  end

  context 'retry logic' do

    context 'when ConnectorsShared::TokenRefreshFailedError is raised' do
      class ExtractorWithTokenRefreshFailure < Connectors::Base::Extractor
        def yield_document_changes(modified_since: nil)
          raise ConnectorsShared::TokenRefreshFailedError
        end
      end

      it 'does not retry and raises the error' do
        extractor = ExtractorWithTokenRefreshFailure.new(
          :content_source_id => content_source_id,
          :service_type => service_type,
          :config => config,
          :features => [],
          :client_proc => client_proc,
          :authorization_data_proc => authorization_data_proc
        )
        expect(extractor).to receive(:yield_document_changes).once.and_call_original

        expect do
          extractor.document_changes { |e| e }
        end.to raise_error(ConnectorsShared::TokenRefreshFailedError)
      end
    end

    context 'when a rate limit error is raised' do
      class RateLimitFailure < StandardError
      end
      class ExtractorWithRateLimitFailure < Connectors::Base::Extractor
        def yield_document_changes(modified_since: nil)
          yield_single_document_change(:identifier => 'the only one') do
            raise RateLimitFailure.new('oops, rate limit')
          end
        end

        private

        def convert_rate_limit_errors
          yield
        rescue RateLimitFailure
          raise ConnectorsShared::ThrottlingError.new(:suspend_until => Time.now + 5.minutes, :cursors => {})
        end
      end

      it 'does not retry and raises the error' do
        extractor = ExtractorWithRateLimitFailure.new(
          :content_source_id => content_source_id,
          :service_type => service_type,
          :config => config,
          :features => [],
          :client_proc => client_proc,
          :authorization_data_proc => authorization_data_proc
        )
        expect(extractor).to receive(:yield_document_changes).once.and_call_original
        expect do
          extractor.document_changes { |e| e }
        end.to raise_error(ConnectorsShared::SuspendedJobError)
      end
    end

    context 'when ConnectorsShared::JobInterruptedError is raised' do
      class ExtractorWithInterruptedJob < Connectors::Base::Extractor
        def yield_document_changes(modified_since: nil)
          raise ConnectorsShared::JobInterruptedError
        end
      end

      it 'does not retry and raises the error' do
        extractor = ExtractorWithInterruptedJob.new(
          :content_source_id => content_source_id,
          :service_type => service_type,
          :config => config,
          :features => [],
          :client_proc => client_proc,
          :authorization_data_proc => authorization_data_proc
        )
        expect(extractor).to receive(:yield_document_changes).once.and_call_original

        expect do
          extractor.document_changes { |e| e }
        end.to raise_error(ConnectorsShared::JobInterruptedError)
      end
    end

    context 'when extracting content raises unexpected errors' do
      let(:error_raised) { RuntimeError.new('fail') }

      class ExtractorWithFailure < Connectors::Base::Extractor
        attr_accessor :setup_failure_count, :documents

        def initialize(setup_failure_count: nil, documents: [], error_to_raise: 'fail', **args)
          super(args)
          @setup_failure_count = setup_failure_count || (MAX_CONNECTION_ATTEMPTS + 1)
          @error_to_raise = error_to_raise
          @documents = documents
        end

        def yield_document_changes(modified_since: nil)
          if setup_failure_count > 0
            self.setup_failure_count -= 1

            raise @error_to_raise
          end
          documents.each do |document|
            yield_single_document_change {
              if document
                yield :index, document, []
              else
                raise('document error')
              end
            }
          end
        end
      end

      context 'more than the number of connection attempts' do
        it 'retries multiple times and finally raises the error' do
          extractor = ExtractorWithFailure.new(
            :content_source_id => content_source_id,
            :service_type => service_type,
            :config => config,
            :features => [],
            :client_proc => client_proc,
            :authorization_data_proc => authorization_data_proc
          )
          expect(extractor).to receive(:yield_document_changes).exactly(described_class::MAX_CONNECTION_ATTEMPTS).times.and_call_original

          expect do
            extractor.document_changes { |e| e }
          end.to raise_error(/fail/)
        end
      end

      context 'less than the number of connection attempts' do
        it 'retries and eventually succeeds' do
          extractor = ExtractorWithFailure.new(
            :content_source_id => content_source_id,
            :service_type => service_type,
            :config => config,
            :features => [],
            :setup_failure_count => 2,
            :client_proc => client_proc,
            :authorization_data_proc => authorization_data_proc
          )
          expect(extractor).to receive(:yield_document_changes).exactly(3).times.and_call_original

          expect do
            extractor.document_changes { |e| e }
          end.to_not raise_error
        end

        context 'individual document errors' do
          let(:extractor) do
            ExtractorWithFailure.new(
              :documents => documents,
              :content_source_id => content_source_id,
              :service_type => service_type,
              :config => config,
              :features => [],
              :setup_failure_count => 0,
              :client_proc => client_proc,
              :authorization_data_proc => authorization_data_proc
            )
          end
          let(:monitor) { ConnectorsShared::Monitor.new(:connector => extractor, :max_error_ratio => max_error_ratio, :window_size => window_size) }
          let(:max_error_ratio) { 0.2 }
          let(:window_size) { 10 }

          before(:each) {
            extractor.monitor = monitor
          }

          context 'a single failure' do
            let(:documents) { ['a', 'a', 'a', nil, 'a', 'a'] }

            it 'moves past a single failure' do
              expect(extractor).to receive(:yield_document_changes).exactly(1).times.and_call_original
              expect(extractor.document_changes.to_a.size).to eq(5)
              expect { monitor.finalize }.to_not raise_error
              expect(monitor.error_queue.size).to eq(1)
            end

            context 'unless a single failure puts you over the ratio overall' do
              let(:max_error_ratio) { 0.15 }
              it 'fails in finalize' do
                extractor.document_changes.to_a
                expect { monitor.finalize }.to raise_error(ConnectorsShared::MaxErrorsInWindowExceededError)
                expect(monitor.error_queue.size).to eq(1)
              end
            end

            context 'unless a single failure puts you over the window\'s ratio' do
              let(:window_size) { 4 }
              it 'fails in document_changes and does not retry' do
                expect(extractor).to receive(:yield_document_changes).exactly(1).times.and_call_original
                expect { extractor.document_changes { |a| a } }.to raise_error(ConnectorsShared::MaxErrorsInWindowExceededError)
                expect(monitor.error_queue.size).to eq(1)
              end
            end
          end
        end
      end

      context 'when those errors are transient server errors' do
        let(:extractor) do
          ExtractorWithFailure.new(
            :content_source_id => content_source_id,
            :service_type => service_type,
            :config => config,
            :features => [],
            :setup_failure_count => 3,
            :error_to_raise => Faraday::ConnectionFailed.new('failed to connect yo'),
            :client_proc => client_proc,
            :authorization_data_proc => authorization_data_proc
          )
        end

        it 'they get wrapped in a ConnectorsShared::TransientServerError with a resume time in the future' do
          expect(extractor).to receive(:yield_document_changes).exactly(3).times.and_call_original

          expect do
            extractor.document_changes { |e| e }
          end.to raise_error do |e|
            expect(e).to be_a(ConnectorsShared::TransientServerError)
            expect(e.cause).to be_a(Faraday::ConnectionFailed)
            expect(e.suspend_until).to be > 1.minute.from_now
          end
        end
      end
    end
  end
end

