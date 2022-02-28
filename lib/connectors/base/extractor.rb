#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'faraday'
require 'httpclient'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/object/deep_dup'
require 'connectors_shared'
require 'date'
require 'active_support/all'

module Connectors
  module Base
    class Extractor
      MAX_CONNECTION_ATTEMPTS = 3
      DEFAULT_CURSOR_KEY = 'all'.freeze

      TRANSIENT_SERVER_ERROR_CLASSES = Set.new(
        [
          Faraday::ConnectionFailed,
          Faraday::SSLError,
          Faraday::TimeoutError,
          HTTPClient::ConnectTimeoutError,
          Net::OpenTimeout
        ]
      )

      attr_reader :content_source, :config, :features, :original_cursors
      attr_accessor :monitor

      delegate(
        :authorization_details,
        :authorization_details!,
        :authorization_data,
        :authorization_data!,
        :access_token,
        :access_token_secret,
        :indexing_allowed?,
        :to => :content_source
      )

      def initialize(content_source:, config:, features:, monitor: ConnectorsShared::Monitor.new(:connector => self))
        @content_source = content_source
        @config = config
        @features = features
        @original_cursors = config.cursors.deep_dup
        @monitor = monitor
      end

      def client!
        @client = nil
        client
      end

      def client
        @client ||= Office365::CustomClient.new(
          :access_token => content_source.access_token,
          :cursors => {},
          :ensure_fresh_auth => lambda do |client|
            if Time.now >= content_source.authorization_details.fetch(:expires_at) - 2.minutes
              content_source.authorization_details!
              client.update_auth_data!(content_source.access_token)
            end
          end
        )
      end

      def retrieve_latest_cursors
        nil
      end

      def with_auth_tokens_and_retry(&block)
        connection_attempts = 0

        begin
          convert_transient_server_errors do
            convert_rate_limit_errors(&block)
          end
        rescue ConnectorsShared::TokenRefreshFailedError => e
          log_error('Could not refresh token, aborting')
          raise e
        rescue Connectors::Work::AbstractExtractorWork::PublishingFailedError => e
          log_error('Could not publish, aborting')
          raise e.reason
        rescue ConnectorsShared::EvictionWithNoProgressError
          log_error('Aborting job because it did not make any progress and cannot be evicted')
          raise
        rescue ConnectorsShared::EvictionError,
          ConnectorsShared::ThrottlingError,
          ConnectorsShared::JobDocumentLimitError,
          ConnectorsShared::MonitoringError,
          ConnectorsShared::JobInterruptedError,
          ConnectorsShared::SecretInvalidError,
          ConnectorsShared::InvalidIndexingConfigurationError => e
          # Don't retry eviction, throttling, document limit, or monitoring errors, let them bubble out
          raise
        rescue StandardError => e
          ConnectorsShared::ExceptionTracking.augment_exception(e)
          connection_attempts += 1
          if connection_attempts >= MAX_CONNECTION_ATTEMPTS
            log_warn("Failed to connect in with_auth_tokens_and_retry Reason: #{e.class}: #{e.message} {:message_id => #{e.id}}")
            log_warn("Retries: #{connection_attempts}/#{MAX_CONNECTION_ATTEMPTS}, giving up.")
            ConnectorsShared::ExceptionTracking.log_exception(e)
            raise e
          else
            log_warn("Failed to connect in with_auth_tokens_and_retry. Reason: #{e.class}: #{e.message} {:message_id => #{e.id}}")
            log_warn("Retries: #{connection_attempts}/#{MAX_CONNECTION_ATTEMPTS}, trying again.")
            retry
          end
        end
      end

      def yield_document_changes(modified_since: nil)
        raise NotImplementedError
      end

      def document_changes(modified_since: nil, &block)
        enum = nil
        Connectors::Stats.measure("extractor.#{Connectors::Stats.class_key(self.class)}.documents") do
          with_auth_tokens_and_retry do
            Connectors::Stats.measure("extractor.#{Connectors::Stats.class_key(self.class)}.yield_documents") do
              counter = 0
              enum = Enumerator.new do |yielder|
                yield_document_changes(:modified_since => modified_since) do |action, change, subextractors|
                  yielder.yield action, change, subextractors
                  counter += 1
                  log_info("Extracted #{counter} documents so far") if counter % 100 == 0
                end
              end
              enum.each(&block) if block_given?
            end
          end
        end
        enum
      end

      def yield_single_document_change(identifier: nil, &block)
        log_debug("Extracting single document for #{identifier}") if identifier
        convert_transient_server_errors do
          convert_rate_limit_errors(&block)
        end
        monitor.note_success
      rescue *fatal_exception_classes => e
        ConnectorsShared::ExceptionTracking.augment_exception(e)
        log_error("Encountered a fall-through error during extraction#{identifying_error_message(identifier)}: #{e.class}: #{e.message} {:message_id => #{e.id}}")
        raise
      rescue StandardError => e
        ConnectorsShared::ExceptionTracking.augment_exception(e)
        log_warn("Encountered error during extraction#{identifying_error_message(identifier)}: #{e.class}: #{e.message} {:message_id => #{e.id}}")
        monitor.note_error(e, :id => e.id)
      end

      def identifying_error_message(identifier)
        identifier.present? ? " of '#{identifier}'" : ''
      end

      def yield_deleted_ids(_ids)
        raise NotImplementedError
      end

      def deleted_ids(ids, &block)
        enum = nil
        Connectors::Stats.measure("extractor.#{Connectors::Stats.class_key(self.class)}.deleted_ids") do
          with_auth_tokens_and_retry do
            Connectors::Stats.measure("extractor.#{Connectors::Stats.class_key(self.class)}.yield_deleted_ids") do
              counter = 0
              enum = Enumerator.new do |yielder|
                yield_deleted_ids(ids) do |id|
                  yielder.yield id
                  counter += 1
                  log_info("Deleted #{counter} documents so far") if counter % 100 == 0
                end
              end
              enum.each(&block) if block_given?
            end
          end
        end
        enum
      end

      def yield_permissions(source_user_id)
        # no-op for content source without DLP support
      end

      def permissions(source_user_id, &block)
        Connectors::Stats.measure("extractor.#{Connectors::Stats.class_key(self.class)}.permissions") do
          with_auth_tokens_and_retry do
            Connectors::Stats.measure("extractor.#{Connectors::Stats.class_key(self.class)}.yield_permissions") do
              yield_permissions(source_user_id) do |permissions|
                log_info("Extracted #{permissions.size} permissions for source user #{source_user_id}")
                block.call(permissions) if block_given?
              end
            end
          end
        end
      end

      ConnectorsShared::Logger::SUPPORTED_LOG_LEVELS.each do |log_level|
        define_method(:"log_#{log_level}") do |message|
          if message.kind_of?(String)
            message = "[Sharepoint]]: #{message}"
          end
          ConnectorsShared::Logger.public_send(log_level, message)
        end
      end

      def convert_transient_server_errors
        yield
      rescue StandardError => e
        raise unless transient_error?(e)

        raise ConnectorsShared::TransientServerError.new(
          "Transient error #{e.class}: #{e.message}",
          :suspend_until => Connectors.config.fetch('transient_server_error_retry_delay_minutes').minutes.from_now,
          :cursors => config.cursors
        )
      end

      def transient_error?(error)
        TRANSIENT_SERVER_ERROR_CLASSES.any? { |error_class| error.kind_of?(error_class) }
      end

      def evictable?
        false
      end

      def cursors_modified_since_start?
        config.cursors != original_cursors
      end

      class << self
        def reset_subextractor_semaphore
          @subextractor_semaphore = nil
        end

        def subextractor_semaphore
          return @subextractor_semaphore if @subextractor_semaphore

          # We allow 2Gb for basic operations: 1Gb for the app's baseline and 1Gb for the main extraction thread
          subextractor_threads = (SharedTogo::JvmMemory.total_heap / 1.gigabyte) - 2
          @subextractor_semaphore =
            if subextractor_threads > 0
              Concurrent::Semaphore.new([subextractor_threads, 2].min)
            else
              # Don't bother using a thread pool, just use the calling thread.
              nil
            end
        end
      end

      def indexed_object_types
        default_object_types
      end

      def default_object_types
        raise NotImplementedError
      end


      private

      def supports_thumbnails?(file_name, file_size)
        AppConfig.content_source_sync_thumbnails_enabled? &&
          features.include?('thumbnails') &&
          Connectors::Subextractor::Thumbnail.supports_file?(file_name, file_size)
      end

      def supports_full_text_extraction?(file_name, file_size)
        features.include?('full_text') && Connectors::Subextractor::FullText.supports_file?(file_name, file_size)
      end

      def features_subextractors(id, file_name, file_size, &block)
        subextractors = []
        if supports_thumbnails?(file_name, file_size) || supports_full_text_extraction?(file_name, file_size)
          log_debug("Running subextractors for file #{file_name} with id: #{id}")
          downloader = download_subextractor(file_size, content_source.service_type, file_name, &block)
          subextractors << thumbnail_subextractor(downloader, id, file_name) if supports_thumbnails?(file_name, file_size)
          subextractors << full_text_subextractor(downloader, id, file_name) if supports_full_text_extraction?(file_name, file_size)
        end
        subextractors
      end

      def convert_rate_limit_errors
        yield # subclasses override this with source-specific handling.
      end

      def fatal_exception_classes
        [
          ConnectorsShared::TokenRefreshFailedError,
          ConnectorsShared::EvictionError,
          ConnectorsShared::ThrottlingError,
          ConnectorsShared::JobDocumentLimitError,
          ConnectorsShared::MonitoringError
        ]
      end

      def download_subextractor(expected_file_size, service_type, file_name, download_type = 'file', &block)
        Connectors::Subextractor::Download.new(
          :expected_file_size => expected_file_size,
          :service_type => service_type,
          :download_type => download_type,
          :file_name => file_name,
          &block
        )
      end

      def full_text_subextractor(downloader, id, name)
        Connectors::Subextractor::FullText.new(downloader, :id => id, :name => name)
      end

      def thumbnail_subextractor(downloader, id, name)
        Connectors::Subextractor::Thumbnail.new(downloader, :id => id, :name => name)
      end
    end
  end
end
