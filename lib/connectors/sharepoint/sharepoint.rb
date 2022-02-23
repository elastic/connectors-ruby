# frozen_string_literal: true
require 'connectors/sharepoint/office365'

module Sharepoint
  class Authorization
    class << self
      def authorization_url
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize'
      end

      def token_credential_uri
        'https://login.microsoftonline.com/common/oauth2/v2.0/token'
      end

      def oauth_scope
        %w[
        User.ReadBasic.All
        Group.Read.All
        Directory.AccessAsUser.All
        Files.Read
        Files.Read.All
        Sites.Read.All
        offline_access
      ]
      end
    end
  end

  class HttpCallWrapper
    def initialize(params)
      features = {}
      @extractor = Sharepoint::Extractor.new(
        content_source: Base::ContentSource.new(access_token: params['access_token']),
        config: Base::Config.new,
        features: features
      )
    end

    def get_document_batch
      results = []
      max = 100

      @extractor.yield_document_changes do |action, doc, subextractors|
        results << {
          :action => action,
          :document => doc,
          :download => nil
        }
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
