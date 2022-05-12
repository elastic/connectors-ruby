# frozen_string_literal: true

require 'hashie/mash'
require 'connectors_sdk/gitlab/extractor'
require 'connectors_sdk/gitlab/config'
require 'connectors_sdk/gitlab/custom_client'
require 'connectors_sdk/gitlab/http_call_wrapper'

describe ConnectorsSdk::GitLab::Extractor do

  let(:projects_json) { connectors_fixture_raw('gitlab/projects_list.json') }
  let(:project_json) { connectors_fixture_raw('gitlab/project.json') }
  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:external_user_json) { connectors_fixture_raw('gitlab/external_user.json') }
  let(:external_users_json) { connectors_fixture_raw('gitlab/external_users.json') }
  let(:project_members_json) { connectors_fixture_raw('gitlab/project_members.json') }
  let(:base_url) { 'https://www.example.com' }

  let(:config) { ConnectorsSdk::GitLab::Config.new(:cursors => {}, :index_permissions => false) }
  let(:cursors) { nil }
  let(:client_proc) do
    proc do
      ConnectorsSdk::GitLab::CustomClient.new(
        :base_url => base_url,
        :api_token => 'token'
      )
    end
  end
  let(:authorization_data_proc) { proc { {} } }

  subject do
    described_class.new(
      :content_source_id => 'gitlab_source_1',
      :service_type => ConnectorsSdk::GitLab::HttpCallWrapper::SERVICE_TYPE,
      :config => config,
      :features => [],
      :client_proc => client_proc,
      :authorization_data_proc => authorization_data_proc
    )
  end

  context '#document_changes' do
    it 'correctly produces one page of documents' do
      stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc")
        .to_return(:status => 200, :body => projects_json)
      result = subject.document_changes.to_a

      expect(result).to_not be_nil
      item = result[0]
      expect(result.size).to eq(100)

      expect(item[0]).to eq(:create_or_update)
      expect(item[1]).to_not be_nil
      expect(item[1][:title]).to_not be_nil
      expect(item[1][:url]).to_not be_nil
      expect(item[2]).to be_nil
    end

    context 'for multi-page results' do
      let(:link_header) { '<https://gitlab.com/api/v4/projects?id_before=35879340&imported=false&membership=false&order_by=id&owned=false&page=1&pagination=keyset&per_page=100&repository_checksum_failed=false&simple=true&sort=desc&starred=false&statistics=false&wiki_checksum_failed=false&with_custom_attributes=false&with_issues_enabled=false&with_merge_requests_enabled=false>; rel="next"' }

      it 'passes the next page into the cursors when needed' do
        stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc")
          .to_return(
            :status => 200,
            :body => projects_json,
            :headers => {
              'Link' => link_header
            }
          )

        subject.document_changes.to_a

        expect(subject.config.cursors).to_not be_nil
        expect(subject.config.cursors).to include(:next_page)
        expect(subject.config.cursors[:next_page]).to eq(link_header)
      end

      context 'when next page' do
        let(:config) { ConnectorsSdk::GitLab::Config.new(:cursors => { :next_page => link_header }) }

        it 'uses the cursor link from parameters' do
          stub_request(:get, "#{base_url}/projects?id_before=35879340&imported=false&membership=false&order_by=id&owned=false&page=1&pagination=keyset&per_page=100&repository_checksum_failed=false&simple=true&sort=desc&starred=false&statistics=false&wiki_checksum_failed=false&with_custom_attributes=false&with_issues_enabled=false&with_merge_requests_enabled=false")
            .to_return(
              :status => 200,
              :body => projects_json
            )

          result = subject.document_changes.to_a

          expect(result).to_not be_nil
          expect(result.size).to eq(100)

          expect(result[0][0]).to eq(:create_or_update)
          expect(result[0][1][:title]).to_not be_nil
          expect(result[0][1][:url]).to_not be_nil
          expect(result[0][2]).to be_nil
        end
      end

      context 'with permissions' do
        let(:config) { ConnectorsSdk::GitLab::Config.new(:cursors => {}, :index_permissions => true ) }

        context 'public projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :public },
              { :id => 2, :visibility => :public }
            ]
          end
          it 'returns empty permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))

            result = subject.document_changes.to_a

            expect(result).to_not be_nil
            expect(result.size).to eq(2)

            expect(result[0][1][:_allow_permissions]).to_not be_present
            expect(result[0][1][:_allow_permissions]).to_not be_present
          end
        end

        context 'internal projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :internal }
            ]
          end

          it 'returns internal in permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))
            stub_request(:get, "#{base_url}/projects/1/members/all")
              .to_return(:status => 200, :body => '[]')

            result = subject.document_changes.to_a

            expect(result).to_not be_nil
            expect(result.size).to eq(1)

            permissions = result[0][1][:_allow_permissions]
            expect(permissions).to be_present
            expect(permissions.size).to eq(1)
            expect(permissions).to include('type:internal')
          end
        end

        context 'private projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :private }
            ]
          end

          it 'returns actual users in permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))
            stub_request(:get, "#{base_url}/projects/1/members/all")
              .to_return(:status => 200, :body => project_members_json)

            result = subject.document_changes.to_a

            expect(result).to_not be_nil
            expect(result.size).to eq(1)

            permissions = result[0][1][:_allow_permissions]
            expect(permissions).to be_present
            expect(permissions.size).to eq(3)
            expect(permissions).to_not include('type:internal')
            expect(permissions).to_not include('user:11', 'user:22', 'user:33')
          end
        end
      end
    end

    context 'for incremental sync' do
      let(:modified_since) { Time.now.days_ago(2) }

      it 'uses the modified after date' do
        date_param = CGI.escape(modified_since.iso8601)

        stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc&last_activity_after=#{date_param}")
          .to_return(:status => 200, :body => projects_json)

        result = subject.document_changes(:modified_since => modified_since).to_a

        expect(result).to_not be_nil
        expect(result.size).to eq(100)
      end
    end
  end

  context '#deleted' do
    let(:existing_id) { 36029109 }
    let(:non_existing_ids) { [123, 234, 345] }

    it 'correctly gets non-existing ids' do
      ids = non_existing_ids.dup.push(existing_id)

      non_existing_ids.each { |id| stub_request(:get, "#{base_url}/projects/#{id}").to_return(:status => 404) }
      stub_request(:get, "#{base_url}/projects/#{existing_id}")
        .to_return(:status => 200, :body => project_json)

      result = subject.deleted_ids(ids).to_a
      expect(result).to eq(non_existing_ids)
    end
  end

  context '#permissions' do
    let(:user_id) { 1 }
    let(:user_name) { 'sytses' }
    let(:external_user_id) { 11422639 }
    let(:external_user_name) { 'PCHINC1' }

    before do
      stub_request(:get, "#{base_url}/users/#{external_user_id}").to_return(:body => external_user_json)
      stub_request(:get, "#{base_url}/users/#{user_id}").to_return(:body => user_json)
      stub_request(:get, "#{base_url}/users?external=true&username=#{external_user_name}").to_return(:body => external_users_json)
      stub_request(:get, "#{base_url}/users?external=true&username=#{user_name}").to_return(:body => '[]')
    end

    it 'correctly sets permissions for internal user' do
      permissions = subject.permissions(user_id).to_a
      expect(permissions).to_not be_empty
      expect(permissions).to include("user:#{user_id}")
      expect(permissions).to include("type:internal")
    end

    it 'correctly sets permissions for external user' do
      permissions = subject.permissions(external_user_id).to_a
      expect(permissions).to_not be_empty
      expect(permissions).to include("user:#{external_user_id}")
      expect(permissions).to_not include("type:internal")
    end

  end
end
