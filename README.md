# Elastic Ruby connectors

> [!IMPORTANT]
> _**Enterprise Search will be discontinued in 9.0.**_
>
> Starting with Elastic version 9.0, we're deprecating the standalone Enterprise Search product with its included features and functionalities (including [Workplace Search](https://www.elastic.co/guide/en/workplace-search/8.x/index.html) and [App Search](https://www.elastic.co/guide/en/app-search/8.x/index.html)). They remain supported in their current form in version 8.x and will only receive security upgrades and fixes. Workplace Search Connector Packages will continue to be supported in their current form throughout 8.x versions, according to our EOL policy: https://www.elastic.co/support/eol.
> We recommend transitioning to our actively developed [Elastic Stack](https://www.elastic.co/elastic-stack) tools for your search use cases. However, if you're still using any Enterprise Search products, we recommend using the latest stable release.
>
> Here are some useful links with more information:
> * Enterprise Search FAQ: https://www.elastic.co/resources/enterprise-search/enterprise-search-faq
> * Migrating to 9.x from Enterprise Search 8.x versions: https://www.elastic.co/guide/en/enterprise-search/current/upgrading-to-9-x.html
___

The home of Elastic connector service and native connectors in Ruby language. This repository contains the framework for customizing Elastic native connectors, or writing your own connectors for advanced use cases.

Any connector implementation in this repository is only for reference, for supported versions please see [connectors-python](https://github.com/elastic/connectors-python).

**The connector will be operated by an administrative user from within Kibana.**

> Note: The connector framework is a tech preview feature. Tech preview features are subject to change and are not covered by the support SLA of general release (GA) features.

Before getting started, review important information about this feature:

- [Terminology](docs/TERMINOLOGY.md)
- [Getting help and providing feedback](docs/SUPPORT.md)
- [Understand the connector protocol](https://github.com/elastic/connectors-python/blob/main/docs/CONNECTOR_PROTOCOL.md)

Build, deploy, and operate your own connector:

- [Building/Deploying a connector](docs/DEVELOPING.md)
- [Operating a connector](https://www.elastic.co/guide/en/enterprise-search/current/connectors.html)

How to publish your connector:

- [Contribute to the repository](docs/CONTRIBUTING.md)

## Other guides

- [Code of Conduct](https://www.elastic.co/community/codeofconduct)
- [Getting Support](docs/SUPPORT.md)
- [Releasing](docs/RELEASING.md)
- [Developer guide](docs/DEVELOPING.md)
- [Security Policy](docs/SECURITY.md)
- [Elastic-internal guide](docs/INTERNAL.md)
- [Connector Protocol](https://github.com/elastic/connectors-python/blob/main/docs/CONNECTOR_PROTOCOL.md)
- [Configuration](docs/CONFIG.md)
- [Terminology](docs/TERMINOLOGY.md)
- [Contributing guide](docs/CONTRIBUTING.md)
