# Elastic Enterprise Search Connectors 

![logo](logo-enterprise-search.png)

The home of Elastic Enterprise Connector Packages. Use connector packages to
customize connectors such as Workplace Search Content Sources for advanced use
cases.

Note #1: The connector framework is a tech preview feature. Tech preview features
are subject to change and are not covered by the support SLA of general release
(GA) features. Elastic plans to promote this feature to GA in a future release.

Note #2: The `main` branch of this repository is currently being heavily reworked. If you want to use the
connector packages now, it would be advisable to check out/fork the [latest stable branch](https://github.com/elastic/connectors/tree/8.3).

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

TBD

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
`config/connectors.yml` that contains all the metadata needed for runtime and
buildtime. It can be used from the dev tree or in a production deployment.

The Gem spec and the connectors use that config file to get
the metadata they need.

The build process might change it on-the-fly when the Gem is created but will
not change the one in the dev tree.

When the connector application is launched, it will pick `config/connectors.yml` by default, 
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
