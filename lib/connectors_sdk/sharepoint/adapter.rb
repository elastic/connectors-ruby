#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/office365/adapter'

module ConnectorsSdk
  module Sharepoint
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
          ConnectorsSdk::Sharepoint::Adapter.share_point_id_to_fp_id(id)
        end
      end

      class FolderGraphItem < Office365::Adapter::FolderGraphItem
        def self.convert_id_to_fp_id(id)
          ConnectorsSdk::Sharepoint::Adapter.share_point_id_to_fp_id(id)
        end
      end

      class PackageGraphItem < Office365::Adapter::PackageGraphItem
        def self.convert_id_to_fp_id(id)
          ConnectorsSdk::Sharepoint::Adapter.share_point_id_to_fp_id(id)
        end
      end
    end
  end
end
