# Elastic Enterprise Search connectors

![logo](logo-enterprise-search.png)

The home of Elastic Enterprise Connector Clients. This repository contains the framework for customizing Elastic Enterprise Search native connectors, or writing your own connectors for advanced use cases.

**The connector will be operated by an administrative user from within Kibana.**

> Note: The connector framework is a tech preview feature. Tech preview features are subject to change and are not covered by the support SLA of general release (GA) features. Elastic plans to promote this feature to GA in a future release.

Before getting started, review important information about this feature:

- [Terminology](#terminology)
- [Getting help and providing feedback](#getting-help-and-providing-feedback)

Build, deploy, and operate your connector:

- [Building a connector](#building-a-connector)
- [Operating the connector](#operating-the-connector)
- [Moving to production](#moving-to-production)

How to publish your connector:

- [Contribute to the repository](#contribute-to-the-repository-)

Reference:

- [Connector protocol reference](docs/CONNECTOR_PROTOCOL.md)

## Terminology

- `connector client` - specific light-weight connector implementation, open-code. Connector clients can be built by Elastic or community built.
- `connector service` - the app that runs the asynchronous loop that calls Elasticsearch on a regular basis to check whether syncs need to happen.
- `connector framework` - framework and libraries used to customize and build connector clients. Basically, it's what this repository is.
- `connector packages` - a previous version of the connector clients. Refer to the [8.3 branch](https://github.com/elastic/connectors-ruby/tree/8.3) if you're looking for connector packages. Also, read more about them in the [custom connector packages guide](https://www.elastic.co/guide/en/workplace-search/8.4/custom-connector-package.html).
- `data source` - file/database/service that provides data to be ingested into Elasticsearch. 

## Getting help and providing feedback

See [Getting Support](docs/SUPPORT.md).

## Building a connector

In this section:

- [Implementing the connector protocol](#implementing-the-connector-protocol)
- [Using the connector framework](#using-the-connector-framework)
- [Operating the connector](#operating-the-connector)
- [Testing the integration](#testing-the-integration)


### Implementing the connector protocol

The [connector protocol](docs/CONNECTOR_PROTOCOL.md) is document-based and building a connector is language- and tool-agnostic.
To create an Elastic connector, you need to implement this protocol. At a high level, you need to create an application (the connector service) that can read and write to a specific document in Elasticsearch that represents the connector. This document "registers" the connector with Kibana, keeps the configuration that is made via the Kibana UI, as well as the scheduling configuration and the state information for the service. You need to update the connector state to keep up with the current status of the connector application and of the third-party data source. You also need to log sync jobs to an additional index, so that the history of synchronization tasks would be available. And of course, you need to write the results of the synchronization to the Elasticsearch document index, created for this connector service.

The procedure to properly implement the protocol _without the connector framework_ is as follows:

- Create a new index for the connector via the Kibana UI - Enterprise Search - Create an Elasticsearch index. Use the `Build a connector` option for an ingestion method.
- Create an API key to work with the connector. It should be done either using the `Generate API key` button, which is available on the next step of the wizard, or by creating a new API key via the Security - API keys - `Create API key`. The second way is more generic and will allow the same API key to be used for multiple connectors.
- By this time, the documents index for the connector is already created and registered in the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) index. It has settings, but no mappings. So if any specific mappings are needed, they should be created manually. 
- Implement the code to synchronize the connector documents via pushing the documents directly to the index that you have created. Make sure that the data is in the format that the mappings expect.
- Implement reading the sync schedule from the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) and synchronize with the data source on schedule.
- Implement the code to log sync jobs to [.elastic-connectors-sync-jobs](docs/CONNECTOR_PROTOCOL.md#jobs-index).
- Implement updating the connector status in the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) index at regular intervals.

### Using the connector framework

Using this connector framework is optional and Ruby-specific. But the framework already has the code for common tasks like scheduling, so it requires less effort to implement. The framework contains a ruby application (we call it the **connector service** or **connector client**), required ruby libraries, and also some code examples that you can use to implement a connector in Ruby. To use it, you'll need a Ruby development environment.

#### Current connector clients

The connector clients implemented in this repository are [mongodb](/lib/connectors/mongodb), [gitlab](/lib/connectors/gitlab) and [example connector](lib/connectors/example). None of those are production ready clients - rather, they are functional examples, which you can use as a base for your own work.

- The `example` connector is the most basic and doesn't have any integration with the third-party data source - it just returns some stub data to ingest.
- The `mongodb` connector is a MongoDB-based connector. It is lacking some features that one would definitely want in production - for example it does not implement any kind of authentication and it only works with a single collection, but it is still a good example of how to use the connector framework for handling the data from this kind of a document storage.
- The `gitlab` connector is the most involved out of the three but is is also missing a lot of features - for one, it only grabs the projects and leaves aside all the other types of content, like files, folders, issues etc. In the current simplified version, it also doesn't synchronize document permissions. But it implements the authentication via an API token, and it has the most developed class structure, which is easily extendable.

#### System Requirements

Under Linux or Macos, you can run the application using Docker or directly on your system.

For the latter you will need:
- rbenv (see [rbenv installation](https://github.com/rbenv/rbenv#installation))
- bundler (see [bundler installation](https://bundler.io/); for version, see [.bundler-version](.bundler-version))
- yq (see [yq installation](https://github.com/mikefarah/yq#install))

#### Windows support

We provide an experimental support for Window 10.

You can run the `win32\install.bat` script to have an unattended installation of Ruby
and the tools we use. Once installed, you can run the `specs` using `make.bat`

#### Implementing the connector protocol with the connector framework

The first few steps for this would be the same [as for skipping the framework and implementing the protocol manually](#implementing-the-connector-protocol): creating a document index, setting up an API key, and updating the document index mappings as needed. The rest of the steps, however, are different.

- Copy the [example connector](lib/connectors/example/connector.rb) into a separate folder under the [connectors](lib/connectors). Rename the class as required.
- Change `self.service_type` and `self.display_name` to match the connector you are implementing. For example, this is how it is done in the provided [mongo connector](lib/connectors/mongodb/connector.rb).

```ruby
      def self.service_type
        'mongo'
      end

      def self.display_name
        'MongoDB'
      end
```

- Change `self.configurable_fields` to provide a list of fields you want to configure via the Kibana UI on connecting the connector.

For example, this is how it is done in the provided [mongo connector](lib/connectors/mongodb/connector.rb).

```ruby
    {
       :host => {
         :label => 'MongoDB Server Hostname'
       },
       :database => {
         :label => 'MongoDB Database'
       },
       :collection => {
         :label => 'MongoDB Collection'
       }
    }
```

If you wanted to also have default values for the fields, you could do it as follows:

```ruby
    {
       :host => {
         :label => 'MongoDB Server Hostname',
         :value => 'localhost:27017'
       },
       :database => {
         :label => 'MongoDB Database',
         :value => 'test-database'
       },
       :collection => {
         :label => 'MongoDB Collection',
         :value => 'test'
       }
    }
```

This way, it's not necessary to set the values in the Kibana UI, unless they differ from the defaults.

- Implement the `health_check` method to return a boolean value, corresponding to the health status of the connector. Currently, the `health_check` method is used to evaluate the connector service state to either `OK` or `FAILURE`, depending on whether the method throws an exception or runs normally. So for example, the [mongo connector](lib/connectors/mongodb/connector.rb) just creates the mongo client to make sure the connection to the database is successful.

```ruby
    def health_check(_params)
      create_client(@host, @database)
    end
```

- Implement the `yield_documents` method to yield documents to the connector framework. It should call `yield` for every document separately and you should yield the documents in the format, matching the mappings that you have defined for the documents index. Example from the [mongo connector](lib/connectors/mongodb/connector.rb):

```ruby
    def yield_documents
      mongodb_client = create_client(@host, @database)
    
      mongodb_client[@collection].find.each do |document|
        doc = document.with_indifferent_access
        transform!(doc)
    
        yield doc
      end
    end
```

Or from the [gitlab connector](lib/connectors/gitlab/connector.rb):

```ruby
    def yield_documents
      next_page_link = nil
      loop do
        next_page_link = @extractor.yield_projects_page(next_page_link) do |projects_chunk|
          projects_chunk.each do |project|
            yield Connectors::GitLab::Adapter.to_es_document(:project, project)
          end
        end
        break unless next_page_link.present?
      end
    end
```

#### Running the connector locally

First, build the code with:

You can run the connector service using our Dockerfile.
```shell
make build
```

Then, you can run the connector service with:

```shell
make run
```

#### Running the connector with Docker

You can also run the connector service using our Dockerfile.

First, build the Docker image with:

```shell
make build-docker
```

Then, you can run the connector service within Docker with:

```shell
make run-docker API_KEY=my-key
```

Where `my-key` is the Elasticsearch API key.

If you need to create an API key for development purposes, you can use the following cURL call on Elasticsearch:

```shell
$ curl --user elastic:changeme -X POST "localhost:9200/_security/api_key?pretty" -H 'Content-Type: application/json' -d'
{
  "name": "my-connector",
  "role_descriptors": {
    "my-connector-role": {
      "cluster": ["all"],
      "index": [
        {
          "names": ["*"],
          "privileges": ["all"]
        }
      ]
    }
  }
}
'
{
  "id" : "4eOWgYIBAYdMiGHcxmKH",
  "name" : "my-connector",
  "api_key" : "zIJThFg9TO6uaYVy57TFSA",
  "encoded" : "NGVPV2dZSUJBWWRNaUdIY3htS0g6eklKVGhGZzlUTzZ1YVlWeTU3VEZTQQ=="
}
```

And then use the `encoded` value:

```
make run-docker API_KEY="NGVPV2dZSUJBWWRNaUdIY3htS0g6eklKVGhGZzlUTzZ1YVlWeTU3VEZTQQ=="
```

#### Local connector properties

Sensitive data, such as API keys, credentials, etc. could also be stored in the [configuration file](config/connectors.yml), provided that it's NOT under source control. Every connector reads this file on creation and is looking for the section called `<service_type>`, where `service_type` is the name that was provided in the corresponding property of the configuration file. You can look at it as a short identifier allowing you to specify which third-party service is behind the connector, or anything to help identify which connector you're running. Example:

```yaml
service_type: gitlab
gitlab:
  api_token: <your-api-key>
```

This way, you're saying that the connector is for GitLab, and there you're providing the API key for GitLab. And it also means that the `GitLab::Connector` class will have a `@local_configuration` variable that will contain whatever is in the `gitlab` section of the configuration file. So inside the connector class, you can access the API key like this:

```ruby
@local_configuration[:api_token]
```

## Operating the connector

As stated above, the connector will be operated by an administrative user from within Kibana.

- The connector operator sets the sync schedule in Kibana, and Kibana writes this to the connector's document in Elasticsearch. So the connector has to read this document to determine when to next sync.
- The connector operator can see the state of the connector within Kibana. So the connector must regularly write its state back to the document, where Kibana can read it.

### Configuring the connector in Kibana

- In Kibana UI, navigate to `Enterprise Search` -
  `Content` - `Elasticsearch indices`.
- Click on the index that you created for the connector while [implementing the connector protocol](#implementing-the-connector-protocol).
- Go to the tab `Configuration` and make sure the following message is displayed:

```text
Your connector <your-service-name> has connected to Enterprise Search successfully.
```

- If needed, set the values of configurable fields in the `Configuration` tab, using the `Edit configuration` button.
- Use the `Set schedule and sync` on the same tab to set the sync schedule and run the sync for the first time.

### Testing the integration

If the connector synchronizes successfully, the documents should appear in `Enterprise Search
Content - Elasticsearch indices - your-index-name` section, on the `Documents` tab.

If the connector didn't specify any configurable fields, it will go into the `connected` status and will try to sync, without requiring any additional configuration via the Kibana UI.

If the connector fails to synchronize, it will change its status to `error`.

## Moving to production

After you've implemented everything correctly, you're ready to go to Production. Before you do this, make sure the following topics are covered:

- No sensitive values are committed to source code repositories.
- No unsecured values are exposed via configurable fields.
- The connector is properly authenticated to the third-party data source.
- The connector implements the connector protocol correctly and does appropriate error handling.

## Contribute to the repository 🚀

We welcome contributors to the project. Before you begin, please read the [Connectors Contributor's Guide](docs/CONTRIBUTING.md).

## Other guides

- [Code of Conduct](https://www.elastic.co/community/codeofconduct)
- [Getting Support](docs/SUPPORT.md)
- [Releasing](docs/RELEASING.md)
- [Developer guide](docs/DEVELOPING.md)
- [Security Policy](docs/SECURITY.md)
- [Elastic-internal guide](docs/INTERNAL.md)
- [Connector Protocol](docs/CONNECTOR_PROTOCOL.md)
