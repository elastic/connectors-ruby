#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'connectors_sdk/base/adapter'
require 'connectors_shared/extraction_utils'
require 'nokogiri'

module ConnectorsSdk
  module Confluence
    class Adapter < ConnectorsSdk::Base::Adapter

      MAX_CONTENT_COMMENTS_TO_INDEX = 50
      LEADING_SLASH_REGEXP = /\A\//

      generate_id_helpers :confluence_space, 'confluence_space'
      generate_id_helpers :confluence_content, 'confluence_content'
      generate_id_helpers :confluence_attachment, 'confluence_attachment'

      def self.swiftype_document_from_confluence_space(space, base_url, permissions = [])
        SpaceNode.new(:node => space, :base_url => base_url, :permissions => permissions).to_swiftype_document
      end

      def self.swiftype_document_from_confluence_content(content, base_url, restrictions = [])
        ContentNode.new(:node => content, :base_url => base_url, :permissions => restrictions).to_swiftype_document
      end

      def self.swiftype_document_from_confluence_attachment(attachment, base_url, restrictions = [])
        AttachmentNode.new(:node => attachment, :base_url => base_url, :permissions => restrictions).to_swiftype_document
      end

      class Node
        attr_reader :node, :base_url, :permissions

        def initialize(node:, base_url:, permissions: [])
          @node = node
          @base_url = base_url
          @base_url = "#{base_url}/" unless @base_url.ends_with?('/')
          @permissions = permissions
        end

        def to_swiftype_document
          {
            :id => id,
            :title => title,
            :url => url,
            :type => ConnectorsSdk::Base::Adapter.normalize_enum(type),
          }.merge(fields)
        end

        def id
          raise NotImplementedError
        end

        def type
          raise NotImplementedError
        end

        def title
          raise NotImplementedError
        end

        def url
          raise NotImplementedError
        end

        def fields
          {}
        end

        protected

        def permissions_hash
          permissions.blank? ? {} : { ConnectorsShared::Constants::ALLOW_FIELD => permissions }
        end
      end

      class SpaceNode < Node
        def id
          Confluence::Adapter.confluence_space_id_to_fp_id(node.fetch('key'))
        end

        def type
          'space'
        end

        def title
          node.name
        end

        def url
          Addressable::URI.join(base_url, (node._links.webui || node._links.self).gsub(LEADING_SLASH_REGEXP, '')).to_s
        end

        def path
          title
        end

        def fields
          permissions_hash
        end
      end

      class ContentNode < Node
        def id
          Confluence::Adapter.confluence_content_id_to_fp_id(node.id)
        end

        def type
          case node.type
          when 'page'
            node.type
          when 'blogpost'
            'blog post'
          else
            ConnectorsShared::ExceptionTracking.capture_message("Unknown confluence type: #{node.type}")
            nil
          end
        end

        def title
          node.title
        end

        def url
          Addressable::URI.join(base_url, node._links.webui.gsub(LEADING_SLASH_REGEXP, '')).to_s
        end

        def body
          text_from_html(node.body.export_view.value)
        end

        def comments
          node.children&.comment&.results&.slice(0, MAX_CONTENT_COMMENTS_TO_INDEX)&.map do |comment|
            text_from_html(comment.body.export_view.value)
          end&.join("\n")
        end

        def description
          [
            node.space&.name,
            node.ancestors&.map(&:title) # 'attachment' type nodes do not have `ancestors`, making this logic incomplete
          ].flatten.select(&:present?).join('/')
        end

        def path
          [
            description,
            title
          ].select(&:present?).join('/')
        end

        def fields
          {
            :description => description,
            :body => body,
            :comments => comments,
            :created_by => node.history&.createdBy&.displayName,
            :project => node.space.try!(:[], :key),

            :created_at => ConnectorsSdk::Base::Adapter.normalize_date(node.history&.createdDate),
            :last_updated => ConnectorsSdk::Base::Adapter.normalize_date(node.history&.lastUpdated&.when)
          }.merge(permissions_hash)
        end

        private

        def text_from_html(raw_html)
          ConnectorsShared::ExtractionUtils.node_descendant_text(Nokogiri::HTML(raw_html))
        end
      end

      class AttachmentNode < ContentNode
        def id
          Confluence::Adapter.confluence_attachment_id_to_fp_id(node.id)
        end

        def type
          'attachment'
        end

        def fields
          mime_type = [
            node.extensions.mediaType,
            ConnectorsSdk::Base::Adapter.mime_type_for_file(node.title)
          ].detect(&:present?)
          extension = ConnectorsSdk::Base::Adapter.extension_for_file(node.title)

          {
            :size => node.extensions.fileSize,
            :container => node&.container&.title,

            :description => description,
            :comments => comments,
            :created_by => node.history&.createdBy&.displayName,
            :project => node.space.try!(:[], :key),

            :created_at => ConnectorsSdk::Base::Adapter.normalize_date(node.history&.createdDate),
            :last_updated => ConnectorsSdk::Base::Adapter.normalize_date(node.history&.lastUpdated&.when)
          }.merge(permissions_hash).tap do |data|
            data[:mime_type] = mime_type if mime_type.present?
            data[:extension] = extension if extension.present?
          end
        end

        def to_swiftype_document
          super.merge(:_fields_to_preserve => ConnectorsSdk::Confluence::Adapter.fields_to_preserve)
        end
      end
    end
  end
end
