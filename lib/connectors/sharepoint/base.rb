module Base
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

  class Base::Adapter
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
end
