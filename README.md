# Connectors
The new home of Elastic Connectors

### System Requirements
- Ruby (see [.ruby-version](.ruby-version))
- bundler 2.2.29

### Setup
1. `make install`

### Lintint
run `make lint`

### Testing
run `make test`

### Copying artifacts to Enterprise Search

Make sure you have [yq](https://github.com/mikefarah/yq/#install) installed, then:

1. run `make build`
1. cd to your ent-search checkout
1. run  `gem uninstall connectors_sdk`
1. copy the artifacts in the `.gems` directory to the `vendor/cache` directory in Enterprise Search repository.
1. run `script/bundle install`

### Running a webserver with a Connector
To run the webserver, several steps need to be made: Java artifacts built, credentials initialized and some other small things work.

First, make sure that you create a unique `api_key` for your service, with:
```shell
make api_key
```

Then, you can run all of them for now with a `make` command:

```shell
make all
```

Consumers will need to use the `api_key` string as the password in
the Authorization header.

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

### Where do I report issues with Connectors?
If something is not working as expected, please open an [issue](https://github.com/elastic/connectors/issues/new).

### Where can I go to get help?
The Workplace Search team at Elastic maintains this library and are happy to help. Try posting your question to the
[Elastic Workplace Search discuss forums](https://discuss.elastic.co/c/workplace-search). Be sure to mention that you're
using Connectors and also let us know what service type you're trying to use, and any errors/issues you are
encountering. You can also find us in the `#enterprise-workplace-search` channel of the
[Elastic Community Slack](elasticstack.slack.com).

### Contribute 🚀
We welcome contributors to the project. Before you begin, a couple notes...
* Read the [Connectors Contributor's Guide](https://github.com/elastic/connectors/blob/main/CONTRIBUTING.md).
* Prior to opening a pull request, please:
    * [Create an issue](https://github.com/elastic/connectors/issues) to discuss the scope of your proposal.
    * Sign the [Contributor License Agreement](https://www.elastic.co/contributor-agreement/). We are not asking you to
      assign copyright to us, but to give us the right to distribute your code without restriction. We ask this of all
      contributors in order to assure our users of the origin and continuing existence of the code. You only need to sign
      the CLA once.
* Please write simple code and concise documentation, when appropriate.
