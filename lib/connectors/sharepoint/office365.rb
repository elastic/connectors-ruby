require 'connectors/base/custom_client'
require 'connectors/base/adapter'
require 'connectors/base/config'
require 'connectors/base/extractor'
require 'connectors_shared'
require 'forwardable'
require 'hashie'

OFFICE365_PERMISSION_SYNC_TIME_SLA = 24.hours
# From FritoPie::Permissions::ALLOW_FIELD
ALLOW_FIELD = '_allow_permissions'


module Office365
  class CustomClient < Connectors::Base::CustomClient
    class ClientError < ConnectorsShared::ClientError
      attr_reader :status_code, :endpoint

      def initialize(status_code, endpoint)
        @status_code = status_code
        @endpoint = endpoint
      end
    end

    class Office365InvalidCursorsError < ClientError; end

    # This is necessary because `Faraday::NestedParamsEncoder.encode` changes the
    # order of params, which Microsoft's download API can't handle for some reason.
    module Office365DownloadParamsEncoder
      class << self
        extend Forwardable
        def_delegators :'Faraday::NestedParamsEncoder', :escape, :decode

        def encode(params)
          params.map do |key, value|
            "#{escape(key)}=#{escape(value)}"
          end.join('&')
        end
      end
    end

    attr_reader :access_token
    attr_accessor :cursors

    BASE_URL = 'https://graph.microsoft.com/v1.0/'.freeze

    def initialize(access_token:, cursors: {}, ensure_fresh_auth: nil)
      @access_token = access_token
      @cursors = cursors || {}
      super(:ensure_fresh_auth => ensure_fresh_auth)
    end

    def update_auth_data!(new_access_token)
      @access_token = new_access_token
      self
    end

    def me
      request_endpoint(:endpoint => 'me')
    end

    def one_drive_drives(fields: [])
      query_params = transform_fields_to_request_query_params(fields)
      response = request_endpoint(:endpoint => 'me/drives/', :query_params => query_params)
      response.value
    end

    def share_point_drives(fields: [])
      # When new Private Team site is created in Sharepoint, permissions take some time to propagate, therefore
      # this site won't be indexed by us until propagation happens. This code tries to also fetch sites from
      # recently created groups (new Private Team site will be there) to reduce friction and index this site
      # earlier.
      # See: https://github.com/elastic/ent-search/pull/3581
      share_point_sites = (sites(:fields => %w[id]) + recent_share_point_group_sites(:fields => %[id]))

      share_point_sites
        .map(&:id)
        .uniq
        .map { |site_id|
          site_drives(site_id, :fields => fields)
        }
        .flatten
        .compact
    end

    def groups(fields: [])
      request_all(:endpoint => 'groups/', :fields => fields)
    end

    def group_root_site(group_id, fields: [])
      query_params = transform_fields_to_request_query_params(fields)

      request_endpoint(:endpoint => "groups/#{group_id}/sites/root", :query_params => query_params)
    end

    def sites(fields: [])
      # This empty search string ends up returning all sites. If we leave it off, the API returns a 400
      # I explicity set the page size here (via :top) because otherwise the API just returns the first ten and
      # does not provide any additional pages.
      request_all(:endpoint => 'sites/', :fields => fields, :additional_query_params => { :search => '', :top => 10 })
    end

    def site_drives(site_id, fields: [])
      document_libraries(
        request_all(:endpoint => "sites/#{site_id}/drives/", :fields => fields)
      )
    rescue ClientError => e
      ConnectorsShared::Logger.info("Received response of #{e.status_code} trying to get drive for Site with Id = #{site_id}: #{e.message}")
      nil
    end

    def list_items(drive_id, fields: [])
      # MSFT Graph API does not have a recursive list items, have to do this dfs style
      stack = [get_root_item(drive_id, ['id']).id]
      # We rely on the id field below to perform our DFS
      fields_with_id = fields.any? ? fields | ['id'] : fields
      while stack.any?
        folder_id = stack.pop
        item_children(drive_id, folder_id, :fields => fields_with_id) do |item|
          if item.folder
            stack << item.id
          end
          yield item
        end

      end
    end

    def item_permissions(drive_id, item_id)
      request_endpoint(:endpoint => "drives/#{drive_id}/items/#{item_id}/permissions").value
    end

    def list_changes(drive_id:, start_delta_link: nil, last_modified: nil)
      query_params = { :'$select' => %w(id content.downloadUrl lastModifiedDateTime lastModifiedBy root deleted file folder package name webUrl createdBy createdDateTime size).join(',') }
      response =
        if start_delta_link.nil?
          endpoint = "drives/#{drive_id}/root/delta"
          request_endpoint(:endpoint => endpoint, :query_params => query_params)
        else
          request_json(:url => start_delta_link, :query_params => query_params)
        end

      loop do
        response.value.each do |change|
          # MSFT Graph API does not allow us to view "changes" in chronological order, so if there is no cursor,
          # we have to iterate through all changes and cherry-pick the ones that are past the `last_modified` Time
          # since to get another cursor, we would have to go through all the changes anyway
          next if last_modified.present? && Time.parse(change.lastModifiedDateTime) < last_modified
          next if change.root # We don't want to index the root of the drive
          yield change
        end

        break if response['@odata.nextLink'].nil?
        response = request_json(:url => response['@odata.nextLink'])
      end

      cursors[drive_id] = response['@odata.deltaLink']
    end

    def get_latest_delta_link(drive_id)
      cursors[drive_id] || exhaustively_get_delta_link(drive_id)
    end

    def exhaustively_get_delta_link(drive_id)
      endpoint = "drives/#{drive_id}/root/delta"

      Connectors::Stats.measure('custom_client.office365.exhaustively_get_delta_link') do
        response = request_endpoint(:endpoint => endpoint, :query_params => { :'$select' => 'id' })

        while next_link = response['@odata.nextLink']
          response = request_json(:url => next_link)
        end

        response['@odata.deltaLink'].split('?').first
      end
    end

    def download_item(download_url)
      request(:url => download_url) do |request|
        request.options.params_encoder = Office365DownloadParamsEncoder
      end.body
    end

    def user_groups(user_id, fields = [])
      (
        request_all(
          :endpoint => "users/#{user_id}/transitiveMemberOf",
          :fields => fields
        ) +
        request_all(
          :endpoint => "users/#{user_id}/ownedObjects",
          :fields => fields
        ).select { |next_object| next_object['@odata.type'] == '#microsoft.graph.group' }
      ).uniq
    end

    private

    def recent_share_point_group_sites(fields: [])
      # group.createdDateTime field is UTC as stated in documentation:
      # https://docs.microsoft.com/en-us/graph/api/resources/group?view=graph-rest-1.0#properties
      created_date_time_threshold = Time.now.utc - OFFICE365_PERMISSION_SYNC_TIME_SLA

      groups(:fields => %w(id createdDateTime))
        .select { |group| group.createdDateTime > created_date_time_threshold }
        .map { |group| group_root_site(group.id, :fields => %w[id]) }.compact
    end

    def document_libraries(drives)
      drives.select { |drive| drive.driveType == 'documentLibrary' }
    end

    def transform_fields_to_request_query_params(fields = [])
      fields.empty? ? {} : { :'$select' => fields.join(',') }
    end

    def request_all(endpoint:, fields: [], additional_query_params: {})
      query_params = transform_fields_to_request_query_params(fields)
      response = request_endpoint(:endpoint => endpoint, :query_params => query_params.merge(additional_query_params))
      items = response.value
      while next_link = response['@odata.nextLink']
        response = request_json(:url => next_link)
        items.concat(response.value)
      end
      items
    end

    def get_root_item(drive_id, fields = [])
      query_params = transform_fields_to_request_query_params(fields)
      request_endpoint(:endpoint => "drives/#{drive_id}/root", :query_params => query_params)
    end

    def item_children(drive_id, item_id, fields: [], &block)
      endpoint = "drives/#{drive_id}/items/#{item_id}/children"
      query_params = transform_fields_to_request_query_params(fields)
      response = request_endpoint(:endpoint => endpoint, :query_params => query_params)

      loop do
        response.value.each(&block)
        next_link = response['@odata.nextLink']
        break if next_link.nil?
        response = request_json(:url => next_link)
      end
    end

    def base_headers
      {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      }
    end

    def raise_any_errors(response, url:, query_params: {})
      if HTTP::Status.successful?(response.status)
        response
      else
        response_body = response.body.to_s
        error_message = begin
          error = JSON.parse(response_body).fetch('error')
          if error['code'] == 'resyncRequired'
            Connectors::Stats.increment('custom_client.office365.error.invalid_cursors')
            raise Office365InvalidCursorsError.new(response.status, url)
          end
          JSON.parse(error.fetch('message')).fetch('Message').strip
        rescue ClientError
          raise
        rescue StandardError
          "got a #{response.status} from #{url} with query #{query_params}"
        end
        raise ClientError.new(response.status, url), error_message
      end
    end

    def request_endpoint(endpoint:, query_params: nil)
      url = "#{BASE_URL}#{endpoint}"
      request_json(:url => url, :query_params => query_params)
    end

    def request_json(url:, query_params: nil)
      response = request(:url => url, :query_params => query_params, :headers => base_headers)
      Hashie::Mash.new(JSON.parse(response.body))
    end

    def request(url:, query_params: nil, headers: nil, &block)
      raise_any_errors(
        get(url, query_params, headers, &block),
        :url => url,
        :query_params => query_params
      )
    end
  end

  class Extractor < Connectors::Base::Extractor
    DRIVE_IDS_CURSOR_KEY = 'drive_ids'

    def yield_document_changes(modified_since: nil, &block)
      drives_to_index.each do |drive|
        drive_id = drive.id
        drive_owner_name = drive.dig(:owner, :user, :displayName)
        drive_name = drive.name

        drive_id_to_delta_link = config.cursors.fetch(DRIVE_IDS_CURSOR_KEY, {})
        begin
          if start_delta_link = drive_id_to_delta_link[drive_id]
            log_debug("Starting an incremental crawl with cursor for #{content_source.service_type.classify} with drive_id: #{drive_id}")
            begin
              yield_changes(drive_id,
                            start_delta_link: start_delta_link, drive_owner_name: drive_owner_name, drive_name: drive_name, &block)
            rescue Office365::CustomClient::Office365InvalidCursorsError
              log_warn("Error listing changes with start_delta_link: #{start_delta_link}, falling back to full crawl")
              yield_drive_items(drive_id, drive_owner_name: drive_owner_name, drive_name: drive_name, &block)
            end
          elsif !modified_since.nil?
            log_debug("Starting an incremental crawl using last_modified (no cursor found) for #{content_source.service_type.classify} with drive_id: #{drive_id}")
            yield_changes(drive_id,
                          last_modified: modified_since, drive_owner_name: drive_owner_name, drive_name: drive_name, &block)
          else
            log_debug("Starting a full crawl #{content_source.service_type.classify} with drive_id: #{drive_id}")
            yield_drive_items(drive_id, drive_owner_name: drive_owner_name, drive_name: drive_name, &block)
          end
        rescue Office365::CustomClient::ClientError => e
          log_warn("Error searching and listing drive #{drive_id}")
          capture_exception(e)
        end
      end

      nil
    end

    def yield_deleted_ids(ids)
      ids.each do |id|
        yield id unless existing_drive_item_ids.include?(id)
      end
    end

    def retrieve_latest_cursors
      delta_links_for_drive_ids = drives_to_index.map(&:id).each_with_object({}) do |drive_id, h|
        h[drive_id] = client.get_latest_delta_link(drive_id)
      rescue Office365::CustomClient::ClientError => e
        log_warn("Error getting delta link for #{drive_id}")
        capture_exception(e)
        raise e
      end

      {
        DRIVE_IDS_CURSOR_KEY => delta_links_for_drive_ids
      }
    end

    def yield_permissions(source_user_id)
      permissions = [source_user_id]
      client.user_groups(source_user_id, %w[id displayName]).each do |next_group|
        # Adding "Members" suffix since that is how the item permissions endpoint return group permissions
        permissions << "#{next_group.displayName} Members"
      end

      yield permissions.uniq
    rescue Connectors::ContentSources::Office365::CustomClient::ClientError => e
      # if a user is deleted, client.user_groups will throw 404 Not Found error, saving another call to get user profile
      if e.status_code == 404
        log_warn("Could not find a user with id #{source_user_id}")
        yield []
      else
        raise
      end
    end

    def client
      @client ||= super.tap do |client|
        client.cursors = config.cursors&.fetch(DRIVE_IDS_CURSOR_KEY, {}) || {}
      end
    end

    private

    def drives
      raise NotImplementedError
    end

    def drives_to_index
      @drives_to_index ||=
        if self.config().index_all_drives?
          drives
        else
          drives.select { |d| config.drive_ids.include?(d.id) }
        end
    end

    def existing_drive_item_ids
      @existing_drive_item_ids ||= Set.new.tap do |ids|
        drives_to_index.each do |drive|
          client.list_items(drive.id) do |item|
            ids << convert_id_to_fp_id(item.id)
          end
        end
      end
    end

    def adapter
      raise NotImplementedError
    end

    def convert_id_to_fp_id(id)
      raise NotImplementedError
    end

    def capture_exception(office365_client_error)
      options = {
        extra: {
          status_code: office365_client_error.status_code,
          endpoint: office365_client_error.endpoint
        }
      }
      ConnectorsShared::ExceptionTracking.capture_exception(office365_client_error, options)
    end

    def yield_drive_items(drive_id, drive_owner_name:, drive_name:, &block)
      client.list_items(drive_id) do |item|
        yield_single_document_change(identifier: "Office365 change: #{item&.id} (#{Office365::Adapter::GraphItem.get_path(item)})") do
          item.drive_owner_name = drive_owner_name
          item.drive_name = drive_name
          yield_create_or_update(drive_id, item, &block)
        end
      end
    end

    def yield_correct_actions_and_converted_item(drive_id, item, &block)
      if item.deleted.nil?
        yield_create_or_update(drive_id, item, &block)
      else
        yield :delete, convert_id_to_fp_id(item.id)
      end
    end

    def yield_changes(drive_id, drive_owner_name:, drive_name:, start_delta_link: nil, last_modified: nil, &block)
      client.list_changes(drive_id: drive_id, start_delta_link: start_delta_link,
                          last_modified: last_modified) do |item|
        yield_single_document_change(identifier: "Office365 change: #{item&.id} (#{Office365::Adapter::GraphItem.get_path(item)})") do
          item.drive_owner_name = drive_owner_name
          item.drive_name = drive_name
          yield_correct_actions_and_converted_item(drive_id, item, &block)
        end
      end
    end

    def yield_create_or_update(drive_id, item)
      item = with_permissions(drive_id, item)

      document = generate_document(item)
      subextractors =
        if downloadable?(item)
          features_subextractors(document.fetch(:id), item.name, item[:size]) do
            client.download_item(item.fetch('@microsoft.graph.downloadUrl'))
          end
        else
          []
        end
      yield :create_or_update, document, subextractors
    end

    def downloadable?(item)
      item.key?('@microsoft.graph.downloadUrl')
    end

    def generate_document(item)
      if item.file
        adapter.swiftype_document_from_file(item)
      elsif item.folder
        adapter.swiftype_document_from_folder(item)
      elsif item.package
        adapter.swiftype_document_from_package(item)
      else
        raise "Unexpected Office 365 item type for item #{item}"
      end
    end

    def with_permissions(drive_id, item)
      item = item.dup
      item.permissions = client.item_permissions(drive_id, item.id) if config.index_permissions
      item
    end
  end

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
          :_fields_to_preserve => Office365::Adapter.fields_to_preserve,
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
            ALLOW_FIELD => item.permissions.map do |next_permission|
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
      def self.convert_id_to_fp_id(id)
        SharePoint::Adapter.share_point_id_to_fp_id(id)
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
