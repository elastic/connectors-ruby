# Elastic Enterprise Search Connectors 

![logo](logo-enterprise-search.png)

The home of Elastic Enterprise Connector Packages. Use connector packages to
customize connectors such as Workplace Search Content Sources for advanced use
cases.

Note #1: The connector framework is a tech preview feature. Tech preview features
are subject to change and are not covered by the support SLA of general release
(GA) features. Elastic plans to promote this feature to GA in a future release.

Note #2: If you are looking for the version of the connector framework that is described in [Bring Your Own Connector](https://www.elastic.co/blog/bring-your-own-enterprise-search-connector) blog article that was describing the version from the 8.3 release, it would be advisable to check out/fork the [relevant branch](https://github.com/elastic/connectors-ruby/tree/8.3).

### System Requirements

Under Linux or Macos, you can run the application using Docker or directly on your system.

For the latter you will need:
- rbenv (see [rbenv installation](https://github.com/rbenv/rbenv#installation))
- bundler (see [bundler installation](https://bundler.io/); for version, see [.bundler-version](./.bundler-version))
- yq (see [yq installation](https://github.com/mikefarah/yq#install))

### Windows support

We provide an experimental support for Window 10.

You can run the `win32\install.bat` script to have an unattended installation of Ruby
and the tools we use. Once installed, you can run the `specs` using `make.bat`

### Running the connector

There's a `Makefile` in the root of the repository. You can run the `make` command to build the project:

```bash
make build
```

This command, apart from building the code, will also create the [configuration file](config/connectors.yml).

You can run the connector application using this command:

```bash
make run
```

However, `make run` needs some required data to be present in the [configuration file](config/connectors.yml), namely, the connector package ID and the service type. There's also some settings for the ICU Analysis Plugin (see below) that are required for applying correct mappings to the content indices. Example of the configuration values:

```yaml
connector_package_id: my-connector-package-id
service_type: gitlab

# how often the connector should check for scheduled sync jobs
idle_timeout: 10

# ICU Analysis Plugin is used (false by default)
# turn this on if the ICU plugin - International Components for Unicode - is installed in your Elasticsearch instance
# see https://www.elastic.co/guide/en/elasticsearch/plugins/current/analysis-icu.html
use_analysis_icu: false
# language to use for the content indices
content_language_code: en
```

Each connector application instance represents a single connector package. This means that currently, it's not supported to try and synchronize multiple service types in the same connector application. It's also recommended to use a separate index for each connector package. Otherwise, it's not guaranteed that the connector will be able to synchronize the data correctly.

The connector package ID is generated when the connector is first registered with Enterprise Search. You can find the connector package ID in the Enterprise Search UI, on the page called `Content` under the `Enterprise Search` tab. When you click the `Create new index` button on this page, you will see several ingestion methods available. One of them is called `Build a connector package` - this is what the current repository represents. The connector package ID is created after you specify the index name and select the index language from a provided select list. This connector package ID should then be added to the `connector_package_id` setting in the [configuration file](config/connectors.yml), together with the language code that you selected for the index as `content_language_code`.

There's also another option to generate a connector package ID _omitting the Kibana UI_ - [via the experimental CLI](#cli_registering_connectors). 

The service_type is the type of service that the connector is connecting to. It's used to determine the correct connector implementation to use.

After the connector is registered and the ID is stored in the configuration file, you can run the connector application using the `make run` command.

NOTE: by default, the connector has no schedule. So when you register a connector, it will NOT be immediately synchronized. See the [Scheduling connectors](#cli_scheduling_connectors) section for more information. 

### Running the connector with Docker

You can run the web server using our Dockerfile.

First, build the Docker image with:

```shell
make build-docker
```

The stdout will display the generated API key.

Then, you can run the server within Docker with:

```shell
make run-docker
```

## The CLI

There's an experimental CLI that you can also use to interact with the connector. 

NOTE: the CLI is a work in progress and though available, should be used at your own risk. It's not yet a fully functional feature and has no parity with the Enterprise Search UI. However, it's a good starting point for experimenting with the connector and it does contain some useful commands.

Running this command in the root of the repository will bring up the CLI menu:

```bash
make exec_cli
```

### <a name="cli_registering_connectors"></a> Registering connectors

The command that you need to use is `register connector with Elasticsearch`. It will bring up the following prompt:

```bash
You already have registered a connector with ID: CHANGEME. Registering a new connector will overwrite the existing one.
Are you sure you want to continue? (y/n)
```

The `CHANGEME` is a placeholder that we're using in the example config file, so you can safely overlook this warning and proceed. In case the connector was already registered, the real connector package ID will be displayed instead. You should confirm the overwrite if you want to discard the previously registered connector and its data. You will also need to manually drop the index that was created for the previously registered connector, especially if you want to use the same name for the newly created index.

Confirming the overwrite will result in the following output:

```bash
Are you sure you want to continue? (y/n)
y
Please enter index name for data ingestion. Use only letters, underscored and dashes.
one
D, [2022-07-13T15:38:49.292685 #97176] DEBUG -- : Connector settings not found for connector_package_id: changeme
I, [2022-07-13T15:38:49.331152 #97176]  INFO -- : Successfully registered connector one with ID 1WGc7YEBRpZatOEsiw4f
Please store connector ID in config file and restart the program.
Press any key to continue...
```

As said, pressing any key will again display the CLI menu. You need to select the `end the program` option to exit the CLI, or just press CTRL+C in the terminal. Then, grab the ID for the newly registered connector and put it into the configuration file under `connector_package_id`, replacing whatever ID there was previously.

### <a name="cli_scheduling_connectors"></a> Scheduling connectors

#### Scheduling connectors via the CLI

The CLI has a menu option called `enable connector scheduling`.

```bash
Please select the command:
--> enable connector scheduling (scheduling_on)
```

Selecting this menu option will result in the following prompt:

```bash
Please enter a valid crontab expression for scheduling. Previous schedule was: * * * * *.
```

In case there was no previous schedule, the empty value will be displayed.
As you can see, the expression is a crontab expression. The syntax is described [here](https://en.wikipedia.org/wiki/Cron#Syntax). You can use an online tool to generate a crontab expression, for example [crontab-generator](https://crontab.guru/).

Suppose we want to change this to every two minutes:

```bash
Please enter a valid crontab expression for scheduling. Previous schedule was: * * * * *.
*/2 * * * *
I, [2022-07-13T16:30:02.840031 #1436]  INFO -- : Successfully updated field scheduling connector 1WGc7YEBRpZatOEsiw4f
Scheduling enabled! Start synchronization to see it in action.
Press any key to continue...
```

As you can see, the scheduling has been updated. Now, the `make run` command will actually try to synchronize the data every two minutes.

#### Scheduling connectors via the Kibana UI

TODO

### Updating configuration values

You can update the git branch, revision and project version in the `connectors.yml` file to your current values by
running this command:

```
make refresh_config
```

This command is also included in every `make run`, so when you re-run the app using the makefile, these values are updated, too.
They are exposed in the root endpoint mentioned above. 

### Configuration

By design, we try to avoid duplicating any metadata in the project, like its
**version**. For this reason, we have one single configuration file in
[config/connectors.yml](config/connectors.yml) that contains all the metadata needed for runtime and
build time. It can be used from the dev tree or in a production deployment.

The Gem spec and the connectors use that config file to get
the metadata they need.

The build process might change it on-the-fly when the Gem is created but will
not change the one in the dev tree.

When the connector application is launched, it will pick [config/connectors.yml](config/connectors.yml) by default, 
but you can provide your own configuration file by using the **CONNECTORS_CONFIG** env.

### Contribute 🚀
We welcome contributors to the project. Before you begin, please read the [Connectors Contributor's Guide](./docs/CONTRIBUTING.md).

### Other guides

- [Code of Conduct](https://www.elastic.co/community/codeofconduct)
- [Getting Support](./docs/SUPPORT.md)
- [Releasing](./docs/RELEASING.md)
- [Developer guide](./docs/DEVELOPING.md)
- [Security Policy](./docs/SECURITY.md)
- [Elastic-internal guide](./docs/INTERNAL.md)
