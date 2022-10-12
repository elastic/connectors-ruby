# Terminology

- `connector client` - specific light-weight connector implementation, open-code. Connector clients can be built by Elastic or Community.
- `native connector` - a connector client built and supported by Elastic, made available by default on Elastic Cloud.
- `connector service` - the app that runs the asynchronous loop that calls Elasticsearch on a regular basis to check whether syncs need to happen.
- `connector packages` - a previous version of the connector clients specific to Workplace Search. Refer to the [8.3 branch](https://github.com/elastic/connectors-ruby/tree/8.3) if you're looking for connector packages. Also, read more about them in the [custom connector packages guide](https://www.elastic.co/guide/en/workplace-search/current/custom-connector-package.html).
- `data source` - file/database/service that provides data to be ingested into Elasticsearch.
- `connector index` - `.elastic-connectors`, the index to hold connector definitions, e.g. name, service type, configuration, scheduling, etc..
- `connector job index` - `.elastic-connectors-sync-jobs`, the index to hold sync job history.
- `connector content index` - The index to hold data for a connector. It has prefix `search-`, and is set in `index_name` of `connector index`.
