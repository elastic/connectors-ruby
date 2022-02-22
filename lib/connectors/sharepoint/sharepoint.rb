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
      max = 10

      @extractor.yield_document_changes do |action, doc, subextractors|
        results << doc
        break if results.size > max
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
        Sharepoint::Adapter.share_point_id_to_fp_id(id)
      end
    end

    class FolderGraphItem < Office365::Adapter::FolderGraphItem
      def self.convert_id_to_fp_id(id)
        Sharepoint::Adapter.share_point_id_to_fp_id(id)
      end
    end

    class PackageGraphItem < Office365::Adapter::PackageGraphItem
      def self.convert_id_to_fp_id(id)
        Sharepoint::Adapter.share_point_id_to_fp_id(id)
      end
    end
  end

  class Extractor < Office365::Extractor

    private

    def convert_id_to_fp_id(id)
      Sharepoint::Adapter.share_point_id_to_fp_id(id)
    end

    def adapter
      Sharepoint::Adapter
    end

    def drives
      client.share_point_drives(:fields => %w(id owner name driveType))
    end
  end
end
