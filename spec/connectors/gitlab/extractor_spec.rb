# frozen_string_literal: true

require 'hashie/mash'
require 'connectors/gitlab/extractor'
require 'connectors/gitlab/custom_client'
require 'connectors/gitlab/connector'

describe Connectors::GitLab::Extractor do
  let(:projects_json) { connectors_fixture_raw('gitlab/projects_list.json') }
  let(:project_json) { connectors_fixture_raw('gitlab/project.json') }
  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:external_user_json) { connectors_fixture_raw('gitlab/external_user.json') }
  let(:external_users_json) { connectors_fixture_raw('gitlab/external_users.json') }
  let(:project_members_json) { connectors_fixture_raw('gitlab/project_members.json') }
  let(:base_url) { 'https://www.example.com' }

  let(:cursors) { nil }
  let(:client_proc) do
    proc do
      Connectors::GitLab::CustomClient.new(
        :base_url => base_url,
        :api_token => 'token'
      )
    end
  end
  let(:authorization_data_proc) { proc { {} } }

  subject do
    Connectors::GitLab::Extractor.new(:base_url => base_url)
  end

  describe '#yield_projects_page' do
    it 'correctly produces one page of documents' do
      stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc")
        .to_return(:status => 200, :body => projects_json)
      link = subject.yield_projects_page do |result|
        expect(result).to_not be_nil
        expect(result.size).to eq(100)

        item = result[0].with_indifferent_access
        expect(item[:id]).to_not be_nil
        expect(item[:name]).to_not be_nil
      end
      expect(link).to be_nil
    end

    context 'for multi-page results' do
      let(:link_header) { '<https://gitlab.com/api/v4/projects?id_before=35879340&imported=false&membership=false&order_by=id&owned=false&page=1&pagination=keyset&per_page=100&repository_checksum_failed=false&sort=desc&starred=false&statistics=false&wiki_checksum_failed=false&with_custom_attributes=false&with_issues_enabled=false&with_merge_requests_enabled=false>; rel="next"' }

      context 'when next page' do
        before(:each) do
          stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc")
            .to_return(
              :status => 200,
              :body => projects_json,
              :headers => {
                'Link' => link_header
              }
            )
          stub_request(:get, "#{base_url}/projects?id_before=35879340&imported=false&membership=false&order_by=id&owned=false&page=1&pagination=keyset&per_page=100&repository_checksum_failed=false&sort=desc&starred=false&statistics=false&wiki_checksum_failed=false&with_custom_attributes=false&with_issues_enabled=false&with_merge_requests_enabled=false")
            .to_return(
              :status => 200,
              :body => '[]'
            )
        end

        it 'returns the cursor link from parameters' do
          link = subject.yield_projects_page do |result|
            expect(result.size).to eq(100)

            item = result[0].with_indifferent_access
            expect(item[:id]).to_not be_nil
            expect(item[:name]).to_not be_nil
          end
          expect(link).to eq(link_header)
        end

        it 'uses the cursor link from parameters' do
          subject.yield_projects_page(link_header) do |result|
            expect(result.size).to eq(0)
          end
        end
      end

      context 'without permissions' do
        context 'private projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :private }
            ]
          end

          it 'returns nothing in permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))
            stub_request(:get, "#{base_url}/projects/1/members/all")
              .to_return(:status => 200, :body => project_members_json)

            subject.yield_projects_page do |result|
              expect(result).to_not be_nil
              expect(result.size).to eq(1)

              permissions = result[0][:_allow_permissions]
              expect(permissions).to_not be_present
            end
          end
        end
      end

      context 'with permissions' do
        let(:config) { Connectors::GitLab::Config.new(:cursors => {}, :index_permissions => true) }

        context 'public projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :public },
              { :id => 2, :visibility => :public }
            ]
          end
          it 'returns empty permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))

            subject.yield_projects_page do |result|
              expect(result).to_not be_nil
              expect(result.size).to eq(2)

              expect(result[0][:_allow_permissions]).to_not be_present
              expect(result[0][:_allow_permissions]).to_not be_present
            end
          end
        end

        context 'internal projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :internal }
            ]
          end

          # TODO: permissions
          xit 'returns internal in permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))
            stub_request(:get, "#{base_url}/projects/1/members/all")
              .to_return(:status => 200, :body => '[]')

            subject.yield_projects_page do |result|
              expect(result).to_not be_nil
              expect(result.size).to eq(1)

              permissions = result[0][:_allow_permissions]
              expect(permissions).to be_present
              expect(permissions.size).to eq(1)
              expect(permissions).to include('type:internal')
            end
          end
        end

        context 'private projects' do
          let(:projects) do
            [
              { :id => 1, :visibility => :private }
            ]
          end
          # TODO: permissions
          xit 'returns actual users in permissions' do
            stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc")
              .to_return(:status => 200, :body => JSON.dump(projects))
            stub_request(:get, "#{base_url}/projects/1/members/all")
              .to_return(:status => 200, :body => project_members_json)

            subject.yield_projects_page do |result|
              expect(result).to_not be_nil
              expect(result.size).to eq(1)

              permissions = result[0][:_allow_permissions]
              expect(permissions).to be_present
              expect(permissions.size).to eq(3)
              expect(permissions).to_not include('type:internal')
              expect(permissions).to_not include('user:11', 'user:22', 'user:33')
            end
          end
        end
      end
    end

    context 'for incremental sync' do
      let(:modified_since) { Time.now.days_ago(2) }

      # TODO: incremental
      xit 'uses the modified after date' do
        date_param = CGI.escape(modified_since.iso8601)

        stub_request(:get, "#{base_url}/projects?order_by=id&owned=true&pagination=keyset&per_page=100&sort=desc&last_activity_after=#{date_param}")
          .to_return(:status => 200, :body => projects_json)

        subject.yield_projects_page(:modified_since => modified_since) do |result|
          expect(result).to_not be_nil
          expect(result.size).to eq(100)
        end
      end
    end
  end

  describe '#deleted' do
    let(:existing_id) { 36029109 }
    let(:non_existing_ids) { [123, 234, 345] }

    # TODO: deletions
    xit 'correctly gets non-existing ids' do
      ids = non_existing_ids.dup.push(existing_id)

      non_existing_ids.each { |id| stub_request(:get, "#{base_url}/projects/#{id}").to_return(:status => 404) }
      stub_request(:get, "#{base_url}/projects/#{existing_id}")
        .to_return(:status => 200, :body => project_json)

      subject.deleted_ids(ids) do |result|
        expect(result).to eq(non_existing_ids)
      end
    end
  end

  describe '#permissions' do
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

    # TODO: permissions
    xit 'correctly sets permissions for internal user' do
      permissions = subject.permissions(user_id) do |result| end
      expect(permissions).to_not be_empty
      expect(permissions).to include("user:#{user_id}")
      expect(permissions).to include('type:internal')
    end

    # TODO: permissions
    xit 'correctly sets permissions for external user' do
      permissions = subject.permissions(external_user_id) do |result| end
      expect(permissions).to_not be_empty
      expect(permissions).to include("user:#{external_user_id}")
      expect(permissions).to_not include('type:internal')
    end
  end
end
