# frozen_string_literal: true

require 'hashie/mash'
require 'connectors_sdk/gitlab/http_call_wrapper'

describe ConnectorsSdk::GitLab::HttpCallWrapper do

  let(:projects_json) { connectors_fixture_raw('gitlab/projects_list.json') }
  let(:project_json) { connectors_fixture_raw('gitlab/project.json') }
  let(:user_json) { connectors_fixture_raw('gitlab/user.json') }
  let(:external_user_json) { connectors_fixture_raw('gitlab/external_user.json') }
  let(:external_users_json) { connectors_fixture_raw('gitlab/external_users.json') }
  let(:base_url) { 'https://www.example.com' }

  context '#document_batch' do
    it 'correctly produces one page of documents' do
      stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc")
        .to_return(:status => 200, :body => projects_json)
      result = subject.document_batch({ :base_url => base_url })

      expect(result).to_not be_nil
      list = result[0]
      expect(list).to_not be_empty
      expect(list.size).to eq(100)

      expect(result[1]).to eq({})
      expect(result[2]).to eq(true)
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

        result = subject.document_batch({ :base_url => base_url })

        expect(result[1]).to eq({ :next_page => link_header })
        expect(result[2]).to eq(false)
      end

      it 'uses the cursor link from parameters' do
        stub_request(:get, "#{base_url}/projects?id_before=35879340&imported=false&membership=false&order_by=id&owned=false&page=1&pagination=keyset&per_page=100&repository_checksum_failed=false&simple=true&sort=desc&starred=false&statistics=false&wiki_checksum_failed=false&with_custom_attributes=false&with_issues_enabled=false&with_merge_requests_enabled=false")
          .to_return(
            :status => 200,
            :body => projects_json
          )

        result = subject.document_batch(
          {
            :base_url => base_url,
            :cursors => { :next_page => link_header }
          }
        )
        expect(result).to_not be_nil
        list = result[0]
        expect(list).to_not be_empty
        expect(list.size).to eq(100)

        expect(result[1]).to eq({})
        expect(result[2]).to eq(true)
      end
    end

    context 'for incremental sync' do
      let(:modified_since) { Time.now.days_ago(2) }

      it 'uses the modified after date passes it onto cursor' do
        date_param = CGI.escape(modified_since.iso8601)

        stub_request(:get, "#{base_url}/projects?order_by=id&pagination=keyset&per_page=100&simple=true&sort=desc&last_activity_after=#{date_param}")
          .to_return(:status => 200, :body => projects_json)

        result = subject.document_batch(
          {
            :base_url => base_url,
            :cursors => {
              :modified_since => modified_since
            }
          }
        )
        expect(result).to_not be_nil
        list = result[0]
        expect(list).to_not be_empty
        expect(list.size).to eq(100)

        expect(result[1]).to eq({ :modified_since => modified_since })
        expect(result[2]).to eq(true)
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

      result = subject.deleted({ :ids => ids, :base_url => base_url })
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
      permissions = subject.permissions({ :base_url => base_url, :user_id => user_id })
      expect(permissions).to_not be_empty
      expect(permissions).to include("user:#{user_id}")
      expect(permissions).to include("type:internal")
    end

    it 'correctly sets permissions for external user' do
      permissions = subject.permissions({ :base_url => base_url, :user_id => external_user_id })
      expect(permissions).to_not be_empty
      expect(permissions).to include("user:#{external_user_id}")
      expect(permissions).to_not include("type:internal")
    end

  end
end
