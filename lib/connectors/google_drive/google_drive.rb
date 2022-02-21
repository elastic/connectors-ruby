i# frozen_string_literal: true

require 'google/apis/drive_v3'
require 'googleauth'
require 'active_support'
require 'active_support/core_ext'
require 'hashie'

CREDENTIALS = File.join(File.dirname(__FILE__), 'ent-search-dev.json')
raise StandardError, "#{CREDENTIALS} not found, run `make credentials`" unless File.exist?(CREDENTIALS)

class PocConstants
  ROOT_GREETING = 'This is the Connectors 2.0 POC. Welcome!'
  LOGGER = Logger.new($stdout)
  SERVICE_ACCOUNT_JSON = CREDENTIALS
  MAX_ORIGINAL_BYTES = 20.megabytes
  USERNAME = 'admin'
  PASSWORD = '1234'
end

class ThirdPartyUnavailableError < StandardError
end

# some abstraction
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

class CopiedGoogleDriveAdapter < AdapterBase
  FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder'

  generate_id_helpers :google_drive, 'google_drive'

  attr_reader :file, :index_permissions, :path

  def self.swiftype_document(file:, index_permissions: false, path: nil)
    new(file: file, index_permissions: index_permissions, path: path).to_swiftype_document
  end

  def initialize(file:, index_permissions: false, path: nil)
    @file = file
    @index_permissions = index_permissions
    @path = path
  end

  def to_swiftype_document
    type = file.mime_type == FOLDER_MIME_TYPE ? 'folder' : 'file'

    updated_by = file.last_modifying_user.try(:display_name)
    updated_by_email = file.last_modifying_user.try(:email_address)
    updated_by_photo_url = file.last_modifying_user.try(:photo_link)

    shared_by = file.sharing_user.try(:display_name)
    shared_by_email = file.sharing_user.try(:email_address)
    shared_by_photo_url = file.sharing_user.try(:photo_link)

    {
      id: CopiedGoogleDriveAdapter.google_drive_id_to_fp_external_id(file.id),
      created_at: normalize_date(file.created_time),
      created_by: first_owner_name,
      created_by_email: first_owner_email,
      updated_at: normalize_date(file.modified_time),
      last_updated: normalize_date(file.modified_time),
      viewed_by_me_at: normalize_date(file.viewed_by_me_time),
      updated_by_me_at: normalize_date(file.modified_by_me_time),
      updated_by: updated_by,
      updated_by_email: updated_by_email,
      updated_by_photo_url: updated_by_photo_url,
      shared_by: shared_by,
      shared_by_email: shared_by_email,
      shared_by_photo_url: shared_by_photo_url,
      size: file.size,
      author: author,
      title: file.name,
      url: file.web_view_link,
      mime_type: file.mime_type,
      extension: extension,
      starred: file.starred,
      type: normalize_enum(type)
    }.tap do |hash|
      normalized_path = normalize_path(path)
      hash[:path] = normalized_path if normalized_path.present?
    end
  end

  private

  def author
    return if file.owners.blank?

    file.owners.map(&:display_name).join(', ')
  end

  def first_owner
    return if file.owners.blank?

    file.owners[0]
  end

  def first_owner_name
    first_owner&.display_name
  end

  def first_owner_email
    first_owner&.email_address
  end

  def extension
    if file.full_file_extension.blank?
      '(no extension)'
    else
      normalize_enum(file.full_file_extension)
    end
  end
end

# extractor
class GoogleDriveExtractor
  DOMAIN_CORPORA = 'domain'
  USER_CORPORA = 'user,allTeamDrives'
  GOOGLE_DRIVE_BATCH_REQUEST_SIZE = 100
  RATE_LIMIT_EXCEEDED_SLEEP_TIME = 0.5
  DRIVE_SPACES = 'drive'
  DRIVE_FOLDER_MIME_TYPE = 'application/vnd.google-apps.folder'
  MAX_RETRIES = 3

  attr_accessor :client

  def initialize
    super
    client!
    resolve_paths # TODO, re-enable
  end

  %w[info error warn debug].each do |log_level|
    define_method(:"log_#{log_level}") do |message|
      message = "External[#{service_name}]: #{message}" if message.is_a?(String)
      PocConstants::LOGGER.public_send(log_level, message)
    end
  end

  def config
    Hashie::Mash.new({ cursors: {} })
  end

  def client!
    @client ||= Google::Apis::DriveV3::DriveService.new.tap do |google_client|
      scope = [
        'https://www.googleapis.com/auth/drive',
        'https://www.googleapis.com/auth/drive.file',
        'https://www.googleapis.com/auth/drive.metadata',
        'https://www.googleapis.com/auth/drive.appdata'
      ]
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(PocConstants::SERVICE_ACCOUNT_JSON),
        scope: scope
      )

      authorizer.fetch_access_token!
      google_client.authorization = authorizer
    end
  end

  def service_name
    'google_drive'
  end

  def health_check
    response = client.get_about(fields: 'user/displayName')
    log_debug("Connection is healthy, got: #{response.to_json}")
    nil
  rescue Google::Apis::AuthorizationError, Google::Apis::ServerError => e
    message = "Encountered an issue while testing the connection to Google Drive: #{e.class}: #{e.message}"
    log_error(message)
    raise ThirdPartyUnavailableError, message
  end

  def get_document_batch(cursor)
    # TODO: validate cursor
    log_info("Retrieving a document batch with cursor: #{cursor}")
    next_page = cursor[:next_page]
    corpora = cursor[:corpora]

    if config.include_domain_docs && (corpora.nil? || (corpora == DOMAIN_CORPORA && next_page.present?))
      get_domain_actions_and_files(cursor)
    elsif corpora == USER_CORPORA || (!config.include_domain_docs && corpora.nil?)
      get_user_actions_and_files(cursor)
    else
      raise "there's nothing left" # TODO: figure out 400's
    end
  end

  def yield_deleted_ids(ids)
    ids.each do |id|
      yield id unless existing_drive_item_ids.include?(id)
    end
  end

  def resolve_paths
    @_parent_ids_to_paths ||= begin
      all_folders = get_all_folders

      get_all_drives.each do |id, drive| # for paths, lets treat drives like top-level folders
        all_folders[id] = { name: drive.name, parents: [] }
      end

      log_info("Resolving folder paths for #{all_folders.size} folders")

      all_folders.each do |_, folder|
        path_ids = [folder.parents.first]
        continue_resolving = path_ids.present?
        while continue_resolving
          top_parent_id = path_ids.first
          next_parent_id = all_folders[top_parent_id]&.parents&.first
          if next_parent_id.blank?
            continue_resolving = false
          else
            path_ids.prepend(next_parent_id)
          end

          if path_ids.size != path_ids.uniq.size # not sure if this is possible, but definitely don't keep going if there's a cycle in the path
            continue_resolving = false
            log_info("Found a cycle in folder path: #{path_ids.join(', ')}")
          end
        end

        folder.path = [
          path_ids.map { |id| all_folders[id]&.name },
          folder.name
        ].flatten.select(&:present?).join('/')
      end
      all_folders
    end
  end

  def download_file(metadata)
    id = metadata['id']
    is_pdf_exportable = metadata['pdf']
    file_size = metadata['size']
    file_name = metadata['name']
    path = metadata['path']
    content =
      if is_pdf_exportable
        client.export_file(id, 'application/pdf', download_dest: StringIO.new).string
      else
        client.get_file(id, download_dest: StringIO.new, supports_all_drives: true).string
      end

    log_debug("Was able to fetch content for file: #{file_name} (#{path})")

    content
  rescue Google::Apis::ServerError, Google::Apis::ClientError, Google::Apis::TransmissionError,
         HTTPClient::ReceiveTimeoutError => e
    file_size_human_readable = is_pdf_exportable ? 'unknown' : file_size
    file_descriptor = "#{id} (#{path || file_name}) of size: '#{file_size_human_readable}'"
    message =
      case e
      when HTTPClient::ReceiveTimeoutError
        "Timed out while extracting file: #{file_descriptor}"
      when Google::Apis::ClientError, Google::Apis::TransmissionError
        "Encountered Google error while extracting file: #{file_descriptor}. Error was: #{e.inspect}"
      when Google::Apis::ServerError
        "While processing file: #{file_descriptor}, encountered transient Google error: #{e.inspect}"
      end
    raise message
  end

  private

  def existing_drive_item_ids
    @existing_drive_item_ids ||= Set.new.tap do |item_ids|
      item_ids.merge(get_item_ids(corpora: DOMAIN_CORPORA)) if config.include_domain_docs
      item_ids.merge(get_item_ids(corpora: USER_CORPORA))
    end
  end

  def get_item_ids(corpora:)
    Set.new.tap do |ids|
      next_page_token = nil
      loop do
        response = get_files(
          corpora,
          next_page_token: next_page_token,
          file_fields: %w[id trashed],
          page_size: 1000
        )

        break if response.nil?

        response.files.each do |file|
          ids << CopiedGoogleDriveAdapter.google_drive_id_to_fp_external_id(file.id) unless file.trashed
        end

        next_page_token = response.next_page_token
        break if next_page_token.nil?
      end
    end
  end

  def convert_rate_limit_errors
    yield
  rescue Google::Apis::RateLimitError
    # TODO: figure out signaling rate limiting
    raise
  end

  def get_domain_actions_and_files(cursor)
    log_info('Fetching documents with domain corpora')
    domain_results = files_batch(cursor, corpora: DOMAIN_CORPORA)
    domain_results[:cursor][:corpora] = USER_CORPORA if domain_results[:cursor][:next_page].blank?
    domain_results
  rescue Google::Apis::ClientError => e
    raise unless e.message.downcase == 'invalid: invalid value'

    log_info('Failed to fetch domain files for potentially "global" domain')
  end

  def get_user_actions_and_files(cursor)
    log_info('Fetching user documents, and all team drive documents')
    user_results = files_batch(cursor, corpora: USER_CORPORA)
    user_results[:cursor] = nil if user_results[:cursor][:next_page].blank?
    user_results
  end

  def transform_file(file)
    if file.trashed
      delete_action(file)
    else
      create_or_update(file)
    end
  end

  def files_batch(cursor, corpora:, file_fields: [])
    modified_since = cursor[:modified_since]
    next_page_token = cursor[:next_page]
    log_debug("Yielding files modified since #{modified_since || 'beginning of time'}")

    response = get_files(corpora, modified_since: modified_since, next_page_token: next_page_token,
                                  file_fields: file_fields)
    if response.nil?
      log_debug('Retrieved 0 files from Google Drive')
    else
      log_debug("Retrieved #{response.files.size} files from Google Drive")
    end

    files =
      if response.nil?
        []
      elsif modified_since
        response.files.select { |file| file.modified_time >= modified_since }
      else
        response.files
      end

    log_debug("#{response.files.size} files are left after filtering by modified_since")

    result_docs = files.map { |file| transform_file(file) }
    results = {
      results: result_docs,
      cursor: {}
    }

    results[:cursor][:next_page] = if files.size < response.files.size || response.next_page_token.nil?
                                     nil
                                   else
                                     response.next_page_token
                                   end
    results
  end

  def delete_action(file)
    log_info("Deleting ID #{file.id} (#{get_path(file)})")
    {
      action: :delete,
      document: { id: CopiedGoogleDriveAdapter.google_drive_id_to_fp_external_id(file.id) }
    }
  end

  def create_or_update(file)
    path = get_path(file)

    document = CopiedGoogleDriveAdapter.swiftype_document(
      file: file,
      path: path
    )

    is_pdf_exportable = pdf_exportable?(file)
    file_name = is_pdf_exportable ? "#{file.name}.pdf" : file.name
    file_size = is_pdf_exportable ? PocConstants::MAX_ORIGINAL_BYTES : file.size&.to_i
    log_debug("Got changes for file:#{file_name} (#{path}) of size:#{file_size} with is_pdf_exportable:#{is_pdf_exportable}")
    download_metadata = {
      id: file.id,
      pdf: is_pdf_exportable,
      size: file_size,
      name: file_name,
      path: path
    }

    {
      action: :create_or_update,
      document: document,
      download: download_metadata
    }
  end

  def get_path(file)
    path = resolve_paths[file.parents&.first]&.path
    path = "#{path}/#{file.name}" if path.present?
    if path.nil?
      log_debug("Was not able to get the path for file #{file.id} (#{file.name}), parents #{file.parents&.to_json}. File will be indexed without a path")
    end
    path
  end

  def pdf_exportable?(file)
    export_formats('application/pdf').include?(file.mime_type)
  end

  def get_files(corpora, modified_since: nil, next_page_token: nil, file_fields: [], page_size: nil)
    params = {
      corpora: corpora,
      spaces: DRIVE_SPACES,
      include_items_from_all_drives: true,
      supports_all_drives: true,
      fields: file_fields.any? ? "files(#{file_fields.join(',')}),nextPageToken" : 'files,nextPageToken'
    }.tap do |api_params|
      api_params[:page_token] = next_page_token unless next_page_token.nil?
      api_params[:order_by] = 'modifiedTime desc' unless modified_since.nil?
      api_params[:page_size] = page_size unless page_size.nil?
    end

    response = nil
    begin
      response = client.list_files(params)
    rescue Google::Apis::ClientError => e
      raise unless e.message.downcase == 'invalid: invalid value'

      log_info("Failed to fetch domain files for potentially global domain (corpora: #{corpora})")
    end
    response
  end

  def get_all_folders
    log_info('Beginning folder retrieval for path resolution')

    params = {
      corpora: 'allDrives',
      include_items_from_all_drives: true,
      supports_all_drives: true,
      fields: 'incompleteSearch,nextPageToken,files(id,name,parents)',
      q: "mimeType='#{DRIVE_FOLDER_MIME_TYPE}'",
      page_size: 1000 # these are small item payloads, so this should be ok and is necessary to get through large data sets
    }

    result = Hashie::Mash.new
    next_page_token = nil
    attempt = 0
    loop do
      params[:page_token] = next_page_token if next_page_token.present?
      begin
        response = client.list_files(params)
        attempt += 1
        if response.incomplete_search
          log_info("Incomplete folders data on attempt #{attempt}. Need to retry.")
          if attempt >= MAX_RETRIES
            log_error('Could not load folders data. Search did not complete')
            break
          else
            next
          end
        end
        response.files.each do |f|
          result[f.id] = { name: f.name, parents: Array.wrap(f.parents) }
        end
        log_info("Retrieved #{response.files.size} new folders from Google Drive, #{result.size} total")

        break if response.next_page_token.blank?

        next_page_token = response.next_page_token
      rescue Google::Apis::ClientError => e
        raise unless e.message.downcase == 'invalid: invalid value'

        log_info("Failed to fetch domain folders for potentially global domain (corpora: #{params[:corpora]})")
        break
      end
    end
    result
  end

  def get_all_drives
    log_info('Beginning drive retrieval for path resolution')

    params = {
      fields: 'nextPageToken,drives(id,name)',
      page_size: 100
    }

    result = Hashie::Mash.new
    next_page_token = nil
    loop do
      params[:page_token] = next_page_token if next_page_token.present?
      begin
        response = client.list_drives(params)
        response.drives.each do |drive|
          result[drive.id] = { name: drive.name }
        end
        log_info("Retrieved #{response.drives.size} new drives from Google Drive, #{result.size} total")

        break if response.next_page_token.blank?

        next_page_token = response.next_page_token
      rescue Google::Apis::ClientError => e
        raise unless e.message.downcase == 'invalid: invalid value'

        log_info("Failed to fetch drives for potentially global domain (corpora: #{params[:corpora]})")
        break
      end
    end
    result
  end

  def about
    @about ||= client.get_about(fields: 'exportFormats')
  end

  def export_formats(mime_type)
    @export_formats ||= {}
    @export_formats[mime_type] ||= about.export_formats.select do |_source_mime_type, export_mime_types|
      export_mime_types.include?(mime_type)
    end.keys.to_set
  rescue StandardError => e
    log_warn("Failed to find export formats for #{mime_type} because of: #{e.class}: #{e.message}")
    []
  end

  def admin_directory_client
    @admin_client ||= Google::Apis::AdminDirectoryV1::DirectoryService.new.tap do |admin_client|
      admin_client.authorization = SecretKeeper::GoogleDrive.refresh_client(
        authorization_details!.fetch(:authorization_data) # force a new fetch of authorization_details
      )
    end
  end
end
