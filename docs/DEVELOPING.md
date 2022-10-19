# Connectors Developer's Guide

So you want to customize Elastic-built connectors, or build your own? Well, you've come to the right place!

After you've made your changes, if you'd like to contribute back, please see the [contributing guide](./CONTRIBUTING.md).

## Requirements
- rbenv (see [rbenv installation](https://github.com/rbenv/rbenv#installation))
- bundler (for version, see [.bundler-version](../.bundler-version))
- yq (see [yq installation](https://github.com/mikefarah/yq#install))

## Setup
1. Fork this repository

## Installing dependencies

From the root level of this repository:

```shell
make install
```

## Code Organization

- `config/connectors.yml`: This is where the config lives. See [Configuration](./CONFIG.md) for detailed explanation.
- `lib/app`: This is where the connector service application and its helpers live.
- `lib/connectors`: This is where the connector clients live. Each directory represent one connector client, e.g. `mongodb`, `gitlab`. The directory name must be the same as the service type. Connectors are hierarchical, so you may find that much of the underlying code for any given connector lives in `lib/connectors/base/**/*.rb`, rather than in the specific connector's implementation.
- `lib/core`: The main components of the connector service application, e.g. `scheduler`, `sync_job_runner`, `output_sync`, etc..
- `lib/stubs`: This is a holdover from migrating from Enterprise Search's monolithic codebase, and these files should eventually be refactored away.
- `lib/utility`: This is where shared utilities, constants, error classes, etc.. live.
- `spec`: This is where the tests live. All tests should match the path of the file/class that they test. For example a `lib/foo/bar.rb` should have a corresponding `spec/foo/bar_spec.rb` test file.

## Add a custom connector

To add a new custom connector, all you have to do is adding a new directory under `lib/connectors`, and make it implement the connector protocol.

1. Copy the [example connector](../lib/connectors/example/connector.rb) into a separate folder under the [connectors](../lib/connectors) (Ignore the [example_attachments] ). Rename the directory to the service type, and rename the class accordingly
    ```shell
    mkdir lib/connectors/{service_type}
    cp lib/connectors/example/connector.rb lib/connectors/{service_type}/connector.rb
    ```

2. Change `self.service_type` and `self.display_name` to match the connector you are implementing.
    ```ruby
    def self.service_type
      'foobar'
    end
    
    def self.display_name
      'Foobar'
    end
    ```

3. Change `self.configurable_fields` to provide a list of fields you want to configure via the Kibana UI when connecting the connector. This method should return a hash, with the format of
    ```ruby
    def self.configurable_fields
      {
        :key => { # The key to uniquely identify the configuration field
          :label => 'label', # The label to be displayed for the field in Kibana
          :value => 'default value', # The default value, optional
        }
      }
    end
    ```

4. Implement the `do_health_check` method to evaluate the connection to the third-party data source, depending on whether the method throws an exception or runs normally. E.g.
    ```ruby
    def do_health_check
      foobar_client.health
    end
    ```

5. Customize `initialize` method if necessary. Make sure `super` is called to assign instance variable `configuration`, which contains all the info required to connect to the third-party data source.

6. Implement the `yield_documents` method to sync data from the third-party data source. This is where your main logic goes to. This method should try to connect to the third-party data source, fetch data and transform to documents and yield them one by one. Each document is a hash and it must contain a key `id`, and it's unique across all the documents in one connector. Below is an example implementation:
    ```ruby
    def yield_documents
      foobar_client.files do |file|
        yield {
          :id => file.id,
          :name => file.name,
          :size => file.size
        }
      end
    end
    ```

7. Register your new connector in [Connectors::REGISTRY](https://github.com/elastic/connectors-ruby/blob/main/lib/connectors/registry.rb). E.g.
    ```ruby
    require_relative 'foobar/connector'
    REGISTRY.register(Connectors::Foobar::Connector.service_type, Connectors::Foobar::Connector)
    ```


## Test your connector

Once you have implemented your new connector, it's time to see how it integrates with Kibana (Refer to [Elastic connectors](https://www.elastic.co/guide/en/enterprise-search/current/connectors.html) on how to operate connectors in Kibana).

1. Make sure you have [Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/setup.html), [Kibana](https://www.elastic.co/guide/en/kibana/current/install.html) and [Enterprise Search](https://www.elastic.co/guide/en/enterprise-search/current/start.html) running. By far the easiest way is to start an Elastic Cloud deployment at https://cloud.elastic.co

2. Go to Kibana, _Enterprise Search_ > _Create an Elasticsearch index_. Use the `Build a connector` option for an ingestion method to create an index.

3. Create an API key to work with the connector. It should be done either using the `Generate API key` button under `Configuration` tab, which is available on the next step of the wizard, or by creating a new API key via _Stack Management_ > _Security_ > _API keys_ > _Create API key_. The second way is more generic and will allow the same API key to be used for multiple connectors.

4. Configure your connector service application (See [Configuration](./CONFIG.md)). You need to configure the followings fields, and leave the rest as default.
    1.  `elasticsearch.cloud_id`: Configure this if the Elasticsearch server is on Cloud. You can find the `cloud_id` on the deployment Overview page.
    2. `elasticsearch.hosts`: Configure this if the Elasticsearch server is deployed on-prem.
    3. `elasticsearch.api_key`: Configure the API key generated in step 3.
    4. `native_mode`: Set it to `false`.
    5. `connector_id`: You can find the `connector_id` in step 3 `Deploy a connector` under `Configuration` tab in Kibana.
    6. `service_type`: Configure it to the service type of your new connector.

5. Run the connector service application with
    ```shell
    make run
    ```

6. Now you should see the message `Your connector {name} has connected to Enterprise Search successfully.` under the `Configuration` tab.

7. The configurable fields should also be displayed. Configure them accordingly.

8. Go to the Overview page, the `Ingestion sync` should be `Connected`. Click the `Sync` button on the top-right corner to start a sync, and see if documents are successfully ingested.

## Building

The repository can generate ruby gems (connectors service itself or shared connectors service library), if needed.

Generate Connector Service gem:
```shell
make build_service_gem
```

Generate shared Connector Services libraries gem:
````shell
make build_utility_gem
````

## Testing
```shell
# ensure code standards
make lint

# run unit tests
make test
```

## IDE and Debugging

This project is fairly simple and conventional as a bundler-based Ruby project, so any popular IDE with ruby support should work fine. The maintaining team uses several IDEs including Intellij, RubyMine, Sublime, and VSCode.

Debugging varies from IDE to IDE, but the gems `ruby-debug-ide`, `pry-remote`, `pry-nav`, and `debase` are all included in the Gemfile, and should be sufficient to power your debugging.
