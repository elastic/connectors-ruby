# Elastic Enterprise Search connectors

![logo](logo-enterprise-search.png)

The home of Elastic Enterprise Connector Clients. This repository contains the framework for customizing Elastic Enterprise Search native connectors, or writing your own connectors for advanced use cases.

[//]: # (The introduction should:)
[//]: # (- Summarize the tools provided in this repository.)
[//]: # (- Summarize the procedures and reference information from this readme and any other docs included in this repo.)
[//]: # (- Introduce any terminology that is our own.)
[//]: # (- Identify this feature as a technical preview.)
[//]: # (Then present a TOC to guide the user through the following sections.)

Note #1: The connector framework is a tech preview feature. Tech preview features are subject to change and are not covered by the support SLA of general release (GA) features. Elastic plans to promote this feature to GA in a future release.

## Terminology

* `connector` - generic term used to refer to both native connectors and connector clients.
* `connector client` - specific light-weight connector implementation, open-code. Not all clients will be supported as native, but we target to have native connectors also offered as clients. Connector clients can be built by Elastic or community built.

## Disambiguation: connectors-ruby and connectors-python

This repository contains connector clients written in Ruby. However, some connectors will also be implemented in Python. The Python connectors are located in a separate repository, [elastic/connectors-python](https://github.com/elastic/connectors-python).

Before getting started, review important information about this feature:

- [Known issues and limitations](#known-issues-and-limitations)
- [Getting help and providing feedback](#getting-help-and-providing-feedback)

Build, deploy, and operate your connector:

- [Building a connector](#building-a-connector)
- [Moving to production](#moving-to-production)
- [Publishing a connector (optional)](#publishing-a-connector-optional)

Reference:

- [Connector protocol reference](#connector-protocol-reference)

## Known issues and limitations

[//]: # (If the only "limitation" is technical preview, we could drop this section.)
- The connector clients implemented in this repository are [mongodb](/lib/connectors/mongodb), [gitlab](/lib/connectors/gitlab) and [stub connector](lib/connectors/stub_connector). None of those are production ready clients - rather, they are functional examples, which you can use as a base for your own work.
- The `stub_connector` is the most basic example that doesn't have any integration with the third-party data source - it just returns some stub data to ingest.
- The `mongodb` connector is a MongoDB-based connector. It is lacking some features that one would definitely want in production - for example it does not implement any kind of authentication and it only works with a single collection, but it is still a good example of how to use the connector framework for handling the data from this kind of a document storage.
- The `gitlab` connector is the most involved out of the three but is is also missing a lot of features - for one, it only grabs the projects and leaves aside all the other types of content, like files, folders, issues etc. In the current simplified version, it also doesn't synchronize document permissions. But it implements the authentication via an API token, and it has the most developed class structure, which is easily extendable.

## Getting help and providing feedback

May want to duplicate the content I put in the Elastic doc: https://github.com/elastic/enterprise-search-pubs/pull/2631

## Building a connector

This section has its own structure, so mini TOC to provide an overview:

- [Implementing the connector protocol](#implementing-the-connector-protocol)
- [Using the connector framework](#using-the-connector-framework)
- [Operating the connector service](#operating-the-connector-service)
- [Operating the connector](#operating-the-connector)
- [Testing the integration](#testing-the-integration)

### Implementing the connector protocol

[//]: # (I see now that the protocol is document-based and building a connector is language- and tool-agnostic. I'm therefore leading with a section that presents a procedure to properly implement the protocol. This is the core task for the developer.)

The [connector protocol](docs/CONNECTOR_PROTOCOL.md) is document-based and building a connector is language- and tool-agnostic. The procedure to properly implement the protocol without using the connector framework is as follows:

- Create a new index for the connector via the Kibana UI - Enterprise Search - Create an Elasticsearch index. Use the `Build a connector` option for an ingestion method.
- Create an API key to work with the connector. It should be done either using the `Generate API key` button, which is available on the next step of the wizard, or by creating a new API key via the Security - API keys - `Create API key`. The second way is more generic and will allow the same API key to be used for multiple connectors.
- By this time, the documents index for the connector is already created and registered in the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) index. It has settings, but no mappings. So if any specific mappings are needed, they should be created manually. 
- Implement the code to synchronize the connector documents via pushing the documents directly to the index that you have created. Make sure that the data is in the format that the mappings expect.
- Implement reading the sync schedule from the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) and synchronize with the data source on schedule.
- Implement the code to log sync jobs to [.elastic-connectors-sync-jobs](docs/CONNECTOR_PROTOCOL.md#jobs-index).
- Implement updating the connector status in the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) index at regular intervals.

### Using the connector framework

Using this connector framework is optional and Ruby-specific. But the framework already has the code for common tasks like scheduling, so it requires less effort to implement.

#### System Requirements

Under Linux or Macos, you can run the application using Docker or directly on your system.

For the latter you will need:
- rbenv (see [rbenv installation](https://github.com/rbenv/rbenv#installation))
- bundler (see [bundler installation](https://bundler.io/); for version, see [.bundler-version](./.bundler-version))
- yq (see [yq installation](https://github.com/mikefarah/yq#install))

#### Windows support

We provide an experimental support for Window 10.

You can run the `win32\install.bat` script to have an unattended installation of Ruby
and the tools we use. Once installed, you can run the `specs` using `make.bat`

### Implementing the connector protocol using the connector framework

The first three steps for this would be the same [as for skipping the framework and implementing the protocol manually](#implementing-the-connector-protocol): creating a document index, setting up an API key, and updating the document index mappings as needed. The rest of the steps, however, are different.

- Copy the [example connector](lib/connectors/example/connector.rb) into a separate folder under the [connectors](lib/connectors). Rename the class as required.
- Change `self.service_type` and `self.display_name` to match the connector you are implementing.
- Change `self.configurable_fields` to provide a list of fields you want to configure via the Kibana UI on connecting the connector.
- Implement the `health_check` method to return a boolean value, corresponding to the health status of the connector. You should return `true` if the third-party data source is working and `false` if it is not.
- Implement the `yield_documents` method to yield documents to the connector framework. It should call `yield` for every document separately and you should yield the documents in the format, matching the mappings that you have defined for the documents index.

### Operating the connector service

#### Running the connector locally

First, build the code with:

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
make run-docker
```

### Operating the connector

After the connector is up and running, it will check the status in the [.elastic-connectors](docs/CONNECTOR_PROTOCOL.md#elastic-connectors) index. If the connector specifies any fields in the `configurable_fields` array, it then will change its status to `needs_configuration` and won't try a sync, until these fields are configured in the Kibana UI in `Enterprise Search
Content - Elasticsearch indices - your-index-name` section, on the `Configuration` tab.

```text
I, [2022-08-09T13:25:37.961144 #20965]  INFO -- : Changing connector status to needs_configuration.
I, [2022-08-09T13:25:37.976296 #20965]  INFO -- : Connector ePa7goIBtEloypCyFur8 is in status "created" and won't sync yet. Connector needs to be in one of the following statuses: ["configured", "connected", "error"] to run.
I, [2022-08-09T13:25:37.976424 #20965]  INFO -- : Sleeping for 60 seconds.
I, [2022-08-09T13:26:37.988348 #20965]  INFO -- : Connector ePa7goIBtEloypCyFur8 is in status "needs_configuration" and won't sync yet. Connector needs to be in one of the following statuses: ["configured", "connected", "error"] to run.

```

After the values for configurable fields are set, the connector will go into the `configured` status and will try to sync.

```text
I, [2022-08-09T13:27:38.015952 #20965]  INFO -- : Connector ePa7goIBtEloypCyFur8 has never synced yet, running initial sync.
I, [2022-08-09T13:27:38.020858 #20965]  INFO -- : Starting sync for connector ePa7goIBtEloypCyFur8.
I, [2022-08-09T13:27:38.149234 #20965]  INFO -- : Deleting 0 documents from index search-sample-connector.
I, [2022-08-09T13:27:38.349054 #20965]  INFO -- : Applied 1 upsert/delete operations to the index search-sample-connector.
I, [2022-08-09T13:27:38.349159 #20965]  INFO -- : Upserted 1 documents into search-sample-connector.
I, [2022-08-09T13:27:38.349188 #20965]  INFO -- : Deleted 0 documents into search-sample-connector.
I, [2022-08-09T13:27:38.438638 #20965]  INFO -- : Successfully synced for connector ePa7goIBtEloypCyFur8.
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

### Contribute 🚀
We welcome contributors to the project. Before you begin, please read the [Connectors Contributor's Guide](./docs/CONTRIBUTING.md).

### Other guides

- [Code of Conduct](https://www.elastic.co/community/codeofconduct)
- [Getting Support](./docs/SUPPORT.md)
- [Releasing](./docs/RELEASING.md)
- [Developer guide](./docs/DEVELOPING.md)
- [Security Policy](./docs/SECURITY.md)
- [Elastic-internal guide](./docs/INTERNAL.md)
- [Connector Protocol](./docs/CONNECTOR_PROTOCOL.md)
