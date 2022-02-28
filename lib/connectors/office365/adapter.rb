#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module Connectors
  module Office365
    class Adapter < Connectors::Base::Adapter
      def self.swiftype_document_from_file(_file)
        raise NotImplementedError
      end

      def self.swiftype_document_from_folder(_folder)
        raise NotImplementedError
      end

      class GraphItem
        attr_reader :item

        def initialize(item)
          @item = item
        end

        def self.convert_id_to_fp_id(_id)
          raise NotImplementedError
        end

        def self.get_path(item)
          parent_reference_path = item.parentReference&.path || ''
          parent_folder_path =
            if parent_reference_path.end_with?('root:')
              ''
            else
              CGI.unescape(parent_reference_path).split('root:').last
            end
          Connectors::Base::Adapter.normalize_path("#{parent_folder_path}/#{item.name}")
        end

        def to_swiftype_document
          {
            :_fields_to_preserve => Connectors::Office365::Adapter.fields_to_preserve,
            :id => self.class.convert_id_to_fp_id(item.id),
            :path => get_path(item),
            :title => item.name,
            :url => item.webUrl,
            :type => Connectors::Base::Adapter.normalize_enum(type),
            :created_by => created_by(item),
            :created_at => Connectors::Base::Adapter.normalize_date(item.createdDateTime),
            :last_updated => Connectors::Base::Adapter.normalize_date(item.lastModifiedDateTime),
            :updated_by => last_modified_by(item),
            :drive_owner => item.drive_owner_name
          }.merge(fields).merge(permissions)
        end

        private

        def get_path(item)
          Office365::Adapter::GraphItem.get_path(item)
        end

        def type
          raise NotImplementedError
        end

        def fields
          raise NotImplementedError
        end

        def created_by(item)
          item.createdBy&.user&.displayName
        end

        def last_modified_by(item)
          item.lastModifiedBy&.user&.displayName
        end

        def permissions
          if item.permissions.present?
            {
              ConnectorsShared::Constants::ALLOW_FIELD => item.permissions.map do |next_permission|
                [
                  next_permission.dig(:grantedTo, :user, :id),
                  next_permission.dig(:grantedTo, :user, :displayName)
                ].compact
              end.flatten.uniq
            }
          else
            {}
          end
        end
      end

      class FileGraphItem < GraphItem
        def self.convert_id_to_fp_id(_id)
          raise NotImplementedError
        end

        private

        def type
          'file'
        end

        def fields
          # FIXME: potentially add `updated_by_email`
          {
            :title => Connectors::Base::Adapter.strip_file_extension(item.name),
            :mime_type => Connectors::Base::Adapter.mime_type_for_file(item.name),
            :extension => Connectors::Base::Adapter.extension_for_file(item.name)
          }
        end
      end

      class FolderGraphItem < GraphItem
        def self.convert_id_to_fp_id(_id)
          raise NotImplementedError
        end

        private

        def type
          'folder'
        end

        def fields
          {
            :title => item.root ? item.drive_name : item.name
          }
        end
      end

      class PackageGraphItem < GraphItem
        def self.convert_id_to_fp_id(_id)
          raise NotImplementedError
        end

        private

        def type
          # MSFT gives packages as 'oneNote' and it should be called 'OneNote'
          item.package.type.classify
        end

        def fields
          {}
        end

      end
    end
  end
end
