# Elastic Enterprise Search Connectors 
The home of Elastic Enterprise Connector Packages. 
Use connector packages to customize connectors such as Workplace Search Content Sources for advanced use cases. 

Note: The connector framework is a tech preview feature. Tech preview features are subject to change and are not covered by the support SLA of general release (GA) features. Elastic plans to promote this feature to GA in a future release.


### System Requirements
- Ruby (see [.ruby-version](.ruby-version))
- bundler 2.2.29
- yq (see [yq installation](https://github.com/mikefarah/yq#install))

### Running a webserver with a Connector
To run the webserver, several steps need to be taken.

First, ensure you have installed necessary dependencies with:
```shell
make install
```

Next, create a unique `api_key` for your service, with:
```shell
make api_key
```

Then, you can run the server with:
```shell
make run
```

Consumers will need to use the `api_key` string as the password in
the basic Authorization header.

### Validating your webserver
You can use any REST client library, or `curl` to hit your webserver once it is up and running. Try:

```shell
$ curl -u elastic:your_generated_api_key http://localhost:9292 | jq
```

Your response should look something like:
```json
{
  "connectors_version": "8.2.0-1647619771",
  "connectors_repository": "git@github.com:elastic/ent-search-connectors.git",
  "connectors_revision": "b6033264a106f8ee39c86d4336d52390ac37f8ae",
  "connector_name": "SharePoint"
}
```


### Connecting Enterprise Search to this webserver

1. First, make a note of the URL at which your connectors webserver is running, and of the `api_key` you used when starting it.
1. Next, in Kibana, go to Workplace Search, and choose the Sources tab.
1. Click "Connect" on the source type that you want ("SharePoint Online", for example), and then choose the "Custom connector" rather than the "Default connector".
1. You will be prompted for the URL and API key from step 1.
1. You will next be prompted to supply OAuth credentials. If you have not yet set up your OAuth app, see the [Workplace Search documentation](https://www.elastic.co/guide/en/workplace-search/current/workplace-search-content-sources.html) for the appropriate content source.
1. After going through the OAuth Authorization Flow, Enterprise Search should be successfully connected to your external Connectors webserver! If you have any issues, please see our guide for [Getting Support](./docs/SUPPORT.md).

### Supported Connectors
This repository is always growing! At the moment, the connectors currently available here are:

- [SharePoint Online](https://www.elastic.co/guide/en/workplace-search/current/sharepoint-online-external.html)

Don't see the connector you're looking for? If it is in the list of [Workplace Search Content Sources](https://www.elastic.co/guide/en/workplace-search/current/workplace-search-content-sources.html), it is probably on our roadmap to move here! See our [Getting Support](./docs/SUPPORT.md) guide for ways to reach out.

Not seeing the connector you want there, either? We encourage community contirubions! See our [Contributors Guide](./docs/CONTRIBUTING.md).

### Sinatra Console
run `make console`

### Configuration

By design, we try to avoid duplicating any metadata in the project, like its
**version**. For this reason, we have one single configuration file in
`config/connectors.yml` that contains all the metadata needed for runtime and
buildtime. It can be used from the dev tree or in a production deployment.

The Gem spec, the connectors and the Sinatra app use that config file to get
the metadata they need.

The build process might change it on-the-fly when the Gem is created but will
not change the one in the dev tree.

When Sinatra is launched, it will pick `config/connectors.yml` by default, 
but you can provide your own configuration file by using the **CONNECTORS_CONFIG** env.

### Contribute 🚀
We welcome contributors to the project. Before you begin, please read the [Connectors Contributor's Guide](./docs/CONTRIBUTING.md).

### Other guides

- [Code of Conduct](https://www.elastic.co/community/codeofconduct)
- [Getting Support](./docs/SUPPORT.md)
- [Developer guide](./docs/DEVELOPING.md)
- [Security Policy](./docs/SECURITY.md)
- [Elastic-internal guide](./docs/INTERNAL.md)
