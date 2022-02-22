require 'faraday'
require 'httpclient'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/numeric/time'
require 'connectors_shared'

module Base
  class ServiceType
    def classify
      'classify'
    end
  end

  class ContentSource
    def authorization_details
      {
        :expires_at => Time.now
      }
    end

    def authorization_details!
    end

    def access_token
      "BEARER A BEAR"
    end

    def service_type
      ServiceType.new
    end
  end

  class CustomClient
    attr_reader :base_url, :middleware, :ensure_fresh_auth

    MAX_RETRIES = 5

    def initialize(base_url: nil, ensure_fresh_auth: nil)
      @base_url = base_url
      @ensure_fresh_auth = ensure_fresh_auth
      middleware!
    end

    def middleware!
      @middleware = Array.wrap(additional_middleware)
      @middleware += Array.wrap(default_middleware)
      @middleware.compact!
    end

    def additional_middleware
      [] # define as needed in subclass
    end

    def default_middleware
      [[Faraday::Request::Retry, retry_config]]
    end

    def retry_config
      {
        :retry_statuses => [429],
        :backoff_factor => 2,
        :max => MAX_RETRIES,
        :interval => 0.05
      }
    end

    [
      :delete,
      :get,
      :head,
      :options,
      :patch,
      :post,
      :put,
    ].each do |http_verb|
      define_method http_verb do |*args, &block|
        ensure_fresh_auth.call(self) if ensure_fresh_auth.present?
        http_client.public_send(http_verb, *args, &block)
      end
    end

    def http_client!
      @http_client = nil
      http_client
    end

    def http_client
      @http_client ||= Faraday.new(base_url) do |faraday|
        middleware.each do |middleware_config|
          faraday.use(*middleware_config)
        end

        faraday.adapter(:httpclient)
      end
    end

    private

    # https://github.com/lostisland/faraday/blob/b09c6db31591dd1a58fffcc0979b0c7d96b5388b/lib/faraday/connection.rb#L171
    METHODS_WITH_BODY = [:post, :put, :patch].freeze

    def send_body?(method)
      METHODS_WITH_BODY.include?(method.to_sym)
    end

    def request_with_throttling(method, url, options = {})
      response =
        if send_body?(method)
          public_send(method, url, options[:body], options[:headers])
        else
          public_send(method, url, options[:params], options[:headers])
        end

      if response.status == 429
        retry_after = response.headers['Retry-After']
        multiplier = options.fetch(:retry_mulitplier, 1)
        retry_after_secs = (retry_after.is_a?(Array) ? retry_after.first.to_i : retry_after.to_i) * multiplier
        retry_after_secs = 60 if retry_after_secs <= 0
        ConnectorsShared::Logger.warn("Exceeded #{self.class} request limits. Going to sleep for #{retry_after_secs} seconds")
        raise ConnectorsShared::ThrottlingError.new(:suspend_until => DateTime.now + retry_after_secs.seconds, :cursors => options[:cursors])
      else
        response
      end
    end
  end

  class Adapter
    def self.fields_to_preserve
      @fields_to_preserve ||= ['body']
        .concat(ConnectorsShared::Constants::THUMBNAIL_FIELDS)
        .concat(ConnectorsShared::Constants::SUBEXTRACTOR_RESERVED_FIELDS)
        .map(&:freeze)
        .freeze
    end

    def self.generate_id_helpers(method_prefix, id_prefix)
      define_singleton_method("#{method_prefix}_id_to_fp_id") do |id|
        "#{id_prefix}_#{id}"
      end

      define_singleton_method("fp_id_is_#{method_prefix}_id?") do |fp_id|
        regex_match = /#{id_prefix}_(.+)$/.match(fp_id)
        regex_match.present? && regex_match.size == 2
      end

      define_singleton_method("fp_id_to_#{method_prefix}_id") do |fp_id|
        regex_match = /#{id_prefix}_(.+)$/.match(fp_id)

        raise ArgumentError, "Invalid id #{fp_id} for source with method prefix #{method_prefix}." if regex_match.nil? || regex_match.length != 2
        regex_match[1]
      end
    end

    def self.mime_type_for_file(file_name)
      ruby_detected_type = MIME::Types.type_for(file_name)
      return ruby_detected_type.first.simplified if ruby_detected_type.present?
      extension = extension_for_file(file_name)
      Connectors::Subextractor::ExtensionMappingUtil.get_mime_types(extension)&.first
    end

    def self.extension_for_file(file_name)
      File.extname(file_name.downcase).delete_prefix!('.')
    end

    def self.strip_file_extension(file_name)
      File.basename(file_name, File.extname(file_name))
    end

    def self.normalize_enum(enum)
      enum&.to_s&.downcase
    end

    def self.normalize_date(date)
      return nil if date.blank?

      case date
      when Date, Time, DateTime, ActiveSupport::TimeWithZone
        date.to_datetime.rfc3339
      else
        begin
          Time.zone.parse(date).to_datetime.rfc3339
        rescue ArgumentError, TypeError => e
          ConnectorsShared::ExceptionTracking.capture_exception(e)
          nil
        end
      end
    end

    def self.normalize_path(path)
      return nil if path.blank?
      return path if path.start_with?('/')
      "/#{path}"
    end

    def self.url_to_path(url)
      return nil if url.blank?
      uri = URI(url)
      return nil if uri.scheme.blank?
      normalize_path(uri.path)
    rescue URI::InvalidURIError, ArgumentError
      nil
    end

    def self.swiftype_document_from_configured_object_base(object_type:, object:, fields:)
      object_as_json = object.as_json

      adapted_object = {
        :type => normalize_enum(object_type)
      }

      fields.each do |field_data|
        remote_field_name = field_data.fetch(:remote)

        value = object_as_json[remote_field_name]
        value = object_as_json.dig(*remote_field_name.split('.')) if value.blank?
        next if value.nil?

        adapted_object[field_data.fetch(:target)] = value
      end

      adapted_object.symbolize_keys
    end
  end

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
        :access_token => 'BLA BLA ACCESS TOKEN',
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
