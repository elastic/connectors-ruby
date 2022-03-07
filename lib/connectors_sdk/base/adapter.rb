#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/object/deep_dup'
require 'connectors_shared'
require 'connectors_shared/extension_mapping_util'
require 'date'
require 'active_support/all'
require 'mime-types'

module ConnectorsSdk
  module Base
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
        ConnectorsShared::ExtensionMappingUtil.get_mime_types(extension)&.first
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

      delegate :normalize_enum, :normalize_date, :normalize_path, :to => :class
    end
  end
end
