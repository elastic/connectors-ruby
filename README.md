# Connectors
The new home of Elastic Connectors

### System Requirements
- jruby (see [.ruby-version](.ruby-version))
- bundler 2.2.29

### Setup
1. `make install`

### Building
run `make build`

### Testing
run `make test`

### Copying artifacts to Enterprise Search
1. run `make build`
2. copy the artifact in `.gems` directory to `vendor/cache` directory in Enterprise Search repository.

### Running a webserver with a Connector
To run the webserver, several steps need to be made: Java artifacts built, credentials initialized and some other small things work. You can run all of them for now with a `make` command.

```shell
make all
```

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
