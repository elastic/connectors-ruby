#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

require 'fixtures/atlassian/confluence'

describe ConnectorsSdk::ConfluenceCloud::Extractor do
  include ConnectorsSdk::Fixtures::Atlassian::Confluence

  let(:service_type) { 'confluence_cloud' }
  let(:base_url) { 'https://swiftypedevelopment.atlassian.net' }
  let(:cloud_id) { 'cloud_id' }
  let(:api_base_url) { 'https://api.atlassian.com/ex/confluence/abc123' }
  let(:content_source_id) { BSON::ObjectId.new }
  let(:oauth_config) { { :client_id => 'client_id', :client_secret => 'client_secret', :base_url => base_url } }
  let(:access_token) { 'access_token' }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  let(:authorization_data) do
    {
      'access_token' => access_token,
      'base_url' => base_url,
      'cloud_id' => cloud_id
    }
  end

  let(:content_id) { '10551886' }

  let(:config) do
    ConnectorsSdk::Atlassian::Config.new(
      :cursors => {},
      :base_url => base_url
    )
  end

  let(:client_proc) do
    proc do
      ConnectorsSdk::ConfluenceCloud::CustomClient.new(
        :base_url => api_base_url,
        :access_token => access_token
      )
    end
  end

  subject do
    described_class.new(
      :content_source_id => content_source_id,
      :service_type => service_type,
      :config => config,
      :features => [],
      :client_proc => client_proc,
      :authorization_data_proc => proc { authorization_data }
    )
  end

  it 'can initialize a client' do
    expect(subject.client.class).to eq(ConnectorsSdk::ConfluenceCloud::CustomClient)
  end

  it 'has the right client middleware' do
    expect(subject.client.middleware).to include([ConnectorsShared::Middleware::RestrictHostnames, { :allowed_hosts => [api_base_url, ConnectorsSdk::Atlassian::CustomClient::MEDIA_API_BASE_URL] }])
  end

  context 'with permissions' do
    before do
      stub_spaces_permissions_request(:keys => ['DLP'], :users => [source_user_id], :groups => [group_name])
    end

    let(:config) do
      ConnectorsSdk::Atlassian::Config.new(
        :cursors => {},
        :base_url => base_url,
        :index_permissions => true
      )
    end
    let(:source_user_id) { 'abcd1234' }
    let(:username) { 'pineapple' }
    let(:group_name) { 'fruit' }
    let(:operations) do
      [
        {
          :operation => 'use',
          :targetType => 'application'
        },
        {
          :operation => 'create_space',
          :targetType => 'application'
        }
      ]
    end
    let!(:user_request) do
      stub_request(:get, "#{api_base_url}/rest/api/user?accountId=#{source_user_id}&expand=operations")
        .to_return(
          :status => 200,
          :body => { :operations => operations }.to_json,
          :headers => { 'Content-Type' => 'application/json' }
        )
    end

    let!(:group_request) do
      stub_request(:get, "#{api_base_url}/rest/api/user/memberof?accountId=#{source_user_id}&limit=200&start=0")
        .to_return(
          :status => 200,
          :body => { :results => [{ :name => group_name }] }.to_json,
          :headers => { 'Content-Type' => 'application/json' }
        )
    end

    it 'looks up the user' do
      expect { |b| subject.permissions(source_user_id, &b) }.to yield_control
      expect(user_request).to have_been_requested
    end

    it 'looks up the user groups' do
      expect { |b| subject.permissions(source_user_id, &b) }.to yield_control
      expect(group_request).to have_been_requested
    end

    context 'when users and groups have space access' do
      it 'yields the permissions' do
        expect { |b| subject.yield_permissions(source_user_id, &b) }
          .to yield_with_args(%W[DLP/group:#{group_name} DLP/user:#{source_user_id}])
      end
    end

    context 'when users and groups have no space access' do
      before do
        stub_spaces_permissions_request(:keys => ['DLP'], :users => [], :groups => [])
      end
      it 'yields no permissions' do
        expect { |b| subject.yield_permissions(source_user_id, &b) }
          .to yield_with_args([])
      end
    end

    context 'when user has access via group only' do
      before do
        stub_spaces_permissions_request(:keys => ['DLP'], :users => [], :groups => [group_name])
      end
      it 'yields permissions' do
        expect { |b| subject.yield_permissions(source_user_id, &b) }
          .to yield_with_args(%W[DLP/group:#{group_name} DLP/user:#{source_user_id}])
      end
    end

    context 'when user has access via user only' do
      before do
        stub_spaces_permissions_request(:keys => ['DLP'], :users => [source_user_id], :groups => [])
      end
      it 'yields permissions' do
        expect { |b| subject.yield_permissions(source_user_id, &b) }
          .to yield_with_args(%W[DLP/group:#{group_name} DLP/user:#{source_user_id}])
      end
    end

    context 'when user has two groups and access to space via one' do
      let(:other_group) { 'apples' }
      before do
        stub_spaces_permissions_request(:keys => ['DLP'], :users => [], :groups => [group_name])
        stub_user_membership_request(user: source_user_id, groups: [group_name, other_group])
      end
      it 'yields permissions' do
        expect { |b| subject.yield_permissions(source_user_id, &b) }
          .to yield_with_args(%W[DLP/group:#{other_group} DLP/group:#{group_name} DLP/user:#{source_user_id}])
      end
    end

    context 'when user is suspended/deleted' do
      let(:operations) { [] }

      it 'yields no permissions' do
        expect { |b| subject.yield_permissions(source_user_id, &b) }
          .to yield_control { |username, perms|
            expect(username).to eq(source_user_id)
            expect(perms).to be_empty
          }
      end
    end

    before do
      stub_expanded_content_request(:id => '1', :type => 'page', :space => 'DLP')
      stub_expanded_content_request(:id => '2', :type => 'attachment', :space => 'DLP', :container_id => '1')
      stub_expanded_content_request(:id => '3', :type => 'page', :space => 'DLP', :users => %w[1234 0000], :groups => %w[abcd zzzz])
      stub_expanded_content_request(:id => '4', :type => 'attachment', :space => 'DLP', :container_id => '3')
      stub_expanded_content_request(:id => '5', :type => 'page', :space => 'DLP', :ancestors => %w[3])
      stub_expanded_content_request(:id => '6', :type => 'attachment', :space => 'DLP', :container_id => '5')
      stub_expanded_content_request(:id => '7', :type => 'page', :space => 'AAS')
      stub_expanded_content_request(:id => '8', :type => 'page', :space => 'AAS', :users => %w[1234 0000], :groups => %w[abcd zzzz])
      stub_expanded_content_request(:id => '10', :type => 'attachment', :space => 'DLP', :users => %w[1234 0000], :groups => %w[abcd zzzz], container_type: 'global', container_id: '9')
    end

    context 'with space without anonymous access' do
      let!(:spaces_request) do
        stub_spaces_permissions_request(:keys => ['DLP'], :users => %w[1234 5678], :groups => %w[abcd efgh])
      end
      let!(:content_request) do
        stub_content_request(:key => 'DLP')
      end

      it 'makes a request to the spaces' do
        subject.document_changes.to_a
        expect(spaces_request).to have_been_requested
        expect(subject.monitor.success_count).to eq(1)
      end

      it 'attaches permissions' do
        spaces = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_space_DLP' }
        expect(spaces.first.fetch('_allow_permissions')).to contain_exactly('user:1234', 'user:5678', 'group:abcd', 'group:efgh')
      end

      context 'with page without restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[1])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_content_1' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/user:1234', 'DLP/user:5678', 'DLP/group:abcd', 'DLP/group:efgh')
        end
      end

      context 'with attachment to a page without restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[2 1])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_attachment_2' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/user:1234', 'DLP/user:5678', 'DLP/group:abcd', 'DLP/group:efgh')
        end
      end

      context 'with page with restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[3])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_content_3' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/group:abcd', 'DLP/group:zzzz', 'DLP/user:0000', 'DLP/user:1234')
        end
      end

      context 'with attachment to a page with restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[4 3])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_attachment_4' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/group:abcd', 'DLP/group:zzzz', 'DLP/user:0000', 'DLP/user:1234')
        end
      end

      context 'with child page without restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[5 3])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_content_5' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/group:abcd', 'DLP/group:zzzz', 'DLP/user:0000', 'DLP/user:1234')
        end
      end

      context 'with attachment to a child page without restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[6 5 3])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_attachment_6' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/group:abcd', 'DLP/group:zzzz', 'DLP/user:0000', 'DLP/user:1234')
        end
      end

      context 'with attachment to a space' do
        let!(:content_request) do
          stub_content_request(:key => 'DLP', :content_ids => %w[10])
        end
        let!(:content_space_request) do
          stub_expanded_content_request(id: '9', space: 'DLP', type: 'space')
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_attachment_10' }
          expect(content_space_request).to_not have_been_requested
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('DLP/user:1234', 'DLP/user:0000', 'DLP/group:abcd', 'DLP/group:zzzz')
        end
      end

      context 'with real life example' do
        let!(:doc_id) { '1952186369' }
        let!(:parent_id) { '1952055429' }
        let!(:space_key) { '716' }
        let!(:content_request) do
          stub_content_request(:key => space_key, :content_ids => %w[1952186369])
        end
        let!(:spaces_request) do
          stub_request(:get, "#{api_base_url}/rest/api/space?expand=permissions&limit=50&start=0")
            .to_return(
              :status => 200,
              :body => expanded_restricted_space_response.to_json
            )
        end
        let!(:expanded_request) do
          stub_request(:get, "#{api_base_url}/rest/api/content/#{doc_id}?expand=body.export_view,history.lastUpdated,ancestors,space,children.comment.body.export_view,container,restrictions.read.restrictions.user,restrictions.read.restrictions.group&status=any")
            .to_return(
              :status => 200,
              :body => expanded_restricted_page_response.to_json
            )
        end
        let!(:expanded_request_ancestor) do
          stub_request(:get, "#{api_base_url}/rest/api/content/#{parent_id}?expand=body.export_view,history.lastUpdated,ancestors,space,children.comment.body.export_view,container,restrictions.read.restrictions.user,restrictions.read.restrictions.group&status=any")
            .to_return(
              :status => 200,
              :body => expanded_restricted_page_anc_response.to_json
            )
        end

        it 'attaches permissions' do
          page = subject.document_changes.to_a.map(&:second).find { |document| document[:id] == "confluence_content_#{doc_id}" }
          expect(page.fetch('_allow_permissions'))
            .to contain_exactly(
              '716/user:5dd6bd2ab5933d0eefaf6fdb',
              '716/user:61d45bdbf3037f0069010539',
              '716/group:restricted group'
            )
        end
      end
    end

    context 'with space with anonymous access' do
      let!(:spaces_request) do
        stub_spaces_permissions_request(:keys => ['AAS'], :users => %w[1234 5678], :groups => %w[abcd efgh], :is_anonymous_access => true)
      end
      let!(:content_request) do
        stub_content_request(:key => 'AAS')
      end

      it 'makes a request to the spaces' do
        subject.document_changes.to_a
        expect(spaces_request).to have_been_requested
        expect(subject.monitor.success_count).to eq(1)
      end

      it 'does not attach permissions' do
        spaces = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_space_AAS' }
        expect(spaces.first).to_not have_key(:_allow_permissions)
      end

      context 'with page without restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'AAS', :content_ids => %w[7])
        end

        it 'does not attach permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_content_7' }
          expect(contents.first).to_not have_key(:_allow_permissions)
        end
      end

      context 'with page with restrictions' do
        let!(:content_request) do
          stub_content_request(:key => 'AAS', :content_ids => %w[8])
        end

        it 'attaches permissions' do
          contents = subject.document_changes.to_a.map(&:second).select { |document| document[:id] == 'confluence_content_8' }
          expect(contents.first.fetch('_allow_permissions'))
            .to contain_exactly('AAS/user:1234', 'AAS/user:0000', 'AAS/group:abcd', 'AAS/group:zzzz')
        end
      end
    end
  end

  context 'attachment downloading' do
    let(:attachment_content) { 'attachment content' }
    let(:attachment_id) { 'attachment_id' }
    let(:parent_id) { 'parent_id' }
    let(:item) do
      {
        :content => {
          :id => attachment_id,
          :container => {
            :id => parent_id
          }
        }.with_indifferent_access
      }
    end

    before do
      stub_request(:get, "#{api_base_url}/wiki/rest/api/content/#{parent_id}/child/attachment/#{attachment_id}/download").to_return(
        :status => 200,
        :body => attachment_content
      )
    end

    it 'downloads from the right path' do
      expect(subject.download(item)).to eq(attachment_content)
    end
  end

  def default_content_response
    {
      :status => 'current',
      :title => 'page title',
      :history => {
        :lastUpdated => {
          :when => '2020-11-19T12:59:19.623-07:00'
        },
        :createdBy => {
          :displayName => 'Oleksiy Kovyrin'
        },
        :createdDate => '2020-11-19T12:59:19.623-07:00'
      },
      :body => {
        :export_view => {
          :value => ''
        }
      },
      :children => {
        :comment => {
          :results => []
        }
      },
      :_links => {
        :webui => ''
      }
    }
  end

  def stub_user_membership_request(user:, groups: [])
    group_results = groups.map { |group_name| { :name => group_name } }
    stub_request(:get, "#{api_base_url}/rest/api/user/memberof?accountId=#{user}&limit=200&start=0")
      .to_return(
        :status => 200,
        :body => { :results => group_results }.to_json,
        :headers => { 'Content-Type' => 'application/json' }
      )
  end

  def stub_spaces_permissions_request(keys:, users: [], groups: [], is_anonymous_access: false)
    stub_spaces_request(:keys => keys, :users => users, :groups => groups, :is_anonymous_access => is_anonymous_access, :expand => 'permissions')
  end

  def stub_spaces_request(keys:, users: [], groups: [], is_anonymous_access: false, expand: nil)
    permissions = []
    permissions << {
      :operation => {
        :operation => 'read'
      },
      :anonymousAccess => true
    } if is_anonymous_access
    users.map do |id|
      permissions <<
        {
          :operation => {
            :operation => 'read'
          },
          :subjects => {
            :user => {
              :results => [
                {
                  :accountId => id
                }
              ]
            }
          }
        }
    end
    groups.map do |name|
      permissions <<
        {
          :operation => {
            :operation => 'read'
          },
          :subjects => {
            :group => {
              :results => [
                {
                  :name => name
                }
              ]
            }
          }
        }
    end
    stub_request(:get, "#{api_base_url}/rest/api/space")
      .with(
        :query => {
          :start => 0,
          :limit => 50,
          :expand => !expand ? nil : expand  # set to `nil` if `expand` is `false`
        }.compact
      )
      .to_return(
        :status => 200,
        :body => {
          :results => keys.map do |next_space_id|
            {
              :key => next_space_id,
              :name => 'Space name',
              :permissions => permissions,
              :_links => {
                :self => '',
                :webui => ''
              }
            }
          end,
          :size => 1,
          :_links => {}
        }.to_json,
        :headers => headers
      )
  end

  def stub_content_request(key:, content_ids: [])
    stub_request(:get, "#{api_base_url}/rest/api/content/search")
      .with(
        :query => {
          :cql => 'space="' + key + '" AND type in (page,blogpost,attachment) order by created asc',
          :expand => '',
          :start => 0,
          :limit => 50
        }
      )
      .to_return(
        :status => 200,
        :body => {
          :results => content_ids.map { |content_id| { :id => content_id } },
          :size => content_ids.size,
          :_links => {}
        }.to_json,
        :headers => headers
      )
  end

  def stub_expanded_content_request(id:, type:, space:, ancestors: [], container_id: '', container_type: '', users: [], groups: [], permissions: true)
    body = {
      :id => id,
      :type => type,
      :space => {
        :key => space,
        :name => 'Space name'
      },
      :container => {
        :id => container_id,
        :title => 'container title',
        :type => container_type
      },
      :ancestors => ancestors.map { |ancestor_id| { :id => ancestor_id } },
      :restrictions => {
        :read => {
          :operation => 'read',
          :restrictions => {
            :user => {
              :results => users.map { |user_id| { :accountId => user_id } }
            },
            :group => {
              :results => groups.map { |name| { :name => name } }
            }
          }
        }
      }
    }.merge(default_content_response)
    body[:extensions] = {
        :mediaType => 'application/pdf',
        :fileSize => 1024
      } if type == 'attachment'

    stub_request(:get, "#{api_base_url}/rest/api/content/#{id}")
      .with(
        :query => {
          :status => 'any',
          :expand => [
            'body.export_view',
            'history.lastUpdated',
            'ancestors',
            'space',
            'children.comment.body.export_view',
            'container',
            ('restrictions.read.restrictions.user' if permissions),
            ('restrictions.read.restrictions.group' if permissions)
          ].compact.join(',')
        }
      )
      .to_return(
        :status => 200,
        :body => body.to_json,
        :headers => headers
      )
  end
end
