# frozen_string_literal: true
require 'connectors/sharepoint/office365'

module Sharepoint

  class HttpCallWrapper
    def initialize(content_source, config)
      features = {}
      @extractor = Sharepoint::Extractor.new(
        content_source: content_source,
        config: config,
        features: features
      )
    end

    def get_document_batch
      results = []

      @extractor.yield_document_changes do |action, doc, subextractors|
        results.add(doc)
      end

      results
    end
  end
  class Adapter < Office365::Adapter
    generate_id_helpers :share_point, 'share_point'

    def self.swiftype_document_from_file(file)
      FileGraphItem.new(file).to_swiftype_document
    end

    def self.swiftype_document_from_folder(folder)
      FolderGraphItem.new(folder).to_swiftype_document
    end

    def self.swiftype_document_from_package(package)
      PackageGraphItem.new(package).to_swiftype_document
    end

    class FileGraphItem < Office365::Adapter::FileGraphItem
      def self.convert_id_to_fp_id(id)
        SharePoint::Adapter.share_point_id_to_fp_id(id)
      end
    end

    class FolderGraphItem < Office365::Adapter::FolderGraphItem
      def self.convert_id_to_fp_id(id)
        SharePoint::Adapter.share_point_id_to_fp_id(id)
      end
    end

    class PackageGraphItem < Office365::Adapter::PackageGraphItem
      def self.convert_id_to_fp_id(id)
        SharePoint::Adapter.share_point_id_to_fp_id(id)
      end
    end
  end

  class AdapterBase
    def self.generate_id_helpers(method_prefix, id_prefix)
      define_singleton_method("#{method_prefix}_id_to_fp_external_id") do |id|
        "#{id_prefix}_#{id}"
      end

      define_singleton_method("fp_external_id_is_#{method_prefix}_id?") do |fp_id|
        regex_match = /#{id_prefix}_(.+)$/.match(fp_id)
        regex_match.present? && regex_match.size == 2
      end

      define_singleton_method("fp_external_id_to_#{method_prefix}_id") do |fp_id|
        regex_match = /#{id_prefix}_(.+)$/.match(fp_id)

        if regex_match.nil? || regex_match.length != 2
          raise ArgumentError,
                "Invalid id #{fp_id} for source with method prefix #{method_prefix}."
        end

        regex_match[1]
      end
    end

    def extension_for_file(file_name)
      File.extname(file_name.downcase).gsub!(/\A\./, '')
    end

    def strip_file_extension(file_name)
      File.basename(file_name, File.extname(file_name))
    end

    def normalize_enum(enum)
      enum&.to_s&.downcase
    end

    def normalize_date(date)
      return nil if date.blank?

      case date
      when Date, Time, DateTime, ActiveSupport::TimeWithZone
        date.to_datetime.rfc3339
      else
        Time.zone.parse(date).to_datetime.rfc3339
      end
    end

    def normalize_path(path)
      return nil if path.blank?
      return path if path.start_with?('/')

      "/#{path}"
    end

    def url_to_path(url)
      return nil if url.blank?

      uri = URI(url)
      return nil if uri.scheme.blank?

      normalize_path(uri.path)
    rescue URI::InvalidURIError, ArgumentError
      nil
    end

    def swiftype_document_from_configured_object_base(object_type:, object:, fields:)
      object_as_json = object.as_json

      adapted_object = {
        type: normalize_enum(object_type)
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

  class Extractor < Office365::Extractor

    private

    def convert_id_to_fp_id(id)
      SharePoint::Adapter.share_point_id_to_fp_id(id)
    end

    def adapter
      SharePoint::Adapter
    end

    def drives
      client.share_point_drives(:fields => %w(id owner name driveType))
    end
  end
end
