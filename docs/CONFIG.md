# Configuration

Configuration lives in `config/connectors.yml`.

Get a copy of configuration with default values:
```shell
cp config/connectors.yml.example config/connectors.yml
```

- `version`: The version of the connector service application, this will be set automatically when the application runs.
- `repository`: The repository to hold the source code of the connector service application.
- `revision`: The specific revision which the connector service application is built on.
- `elasticsearch`: Elasticsearch connection configurations.
    - `cloud_id`: The cloud ID of the Elasticsearch deployment, if it's deployed on Elastic Cloud. Either this or `hosts` have to be configured.
    - `hosts`: The hosts of the Elasticsearch deployment. This will be ignored if `cloud_id` is configured. Either this or `cloud_id` have to be configured.
    - `api_key`: The API key to connect to the Elasticsearch server.
    - `retry_on_failure`: Number of retries when request fails before raising an exception. Defaults to 3.
    - `request_timeout`: The request timeout to be passed to transport in options. Defaults to 120.
    - `disable_warnings`: Whether to display warnings in the log. Defaults to `true`.
    - `trace`: Whether to use the default tracer. Defaults to `false`.
    - `log`: Whether to use logger when connecting to Elasticsearch. Defaults to `false`.
- `thread_pool`: Thread pool configurations.
    - `min_threads`: When a new task is submitted and fewer than `min_threads` are running, a new thread is created. Defaults to `0`.
    - `max_threads`: The maximum number of threads to be created. Defaults to `5`.
    - `max_queue`: The maximum number of tasks allowed in the work queue at any one time; a value of zero means the queue may grow without bound. Defaults to `100`.
- `log_level`: Log level. Defaults to `info`.
- `ecs_logging`: Whether to output the log ECS compatible format, which is required when the application is deployed on Elastic Cloud. Defaults to `true`.
- `poll_interval`: The interval (in seconds) to poll connectors from Elasticsearch. Defaults to `3`.
- `termination_timeout`: The maximum number of seconds to wait for the pool shutdown to complete. Defaults to `60`.
- `heartbeat_interval`: The interval (in seconds) to send a new heartbeat for a connector. Defaults to `1800`.
- `job_cleanup_interval`: The interval (in seconds) to run a job cleanup task. Defaults to `300`.
- `native_mode`: Whether to run the application in `native mode`. Defaults to `true`.
- `connector_id`: The ID of the connector that the application will sync data for. This is required when `native_mode` is `false`.
- `service_type`: The service type of the connector that the application will sync data for. This is required when `native_mode` is `false`. 
- `max_ingestion_queue_size`: When number of documents in bulk operation exceeds this number, a bulk request is issued to Elasticsearch. Defaults to `500`.
- `max_ingestion_queue_bytes`: When byte size of bulk operation exceeds this number, a bulk request is issued to Elasticsearch. Defaults to `5242880`.

## Run the connector service on Elastic Cloud

When you have an Enterprise Search deployment on Elastic Cloud post 8.5.0, the connector service is automatically deployed. The connector service can only run in native mode on Elastic Cloud (i.e. `native_mode` is always `true`), and the Elasticsearch connection configurations (i.e. `cloud_id`, `hosts`, `api_key`) will be overridden, and a special Cloud user `cloud-internal-enterprise_search-server` will be used for Elasticsearch connection, which will have proper privilege on the connector index (`.elastic-connectors`), the connector job index (`.elastic-connectors-sync-jobs`) and the connector content indices (`search-*`).

## Run the connector service on-prem

### Run the connector service in native mode

1. Set `native_mode` to `true`
2. Generate the API key via _Stack Management_ > _Security_ > _API keys_ > _Create API key_. Make sure the API key has at least the privileges to `manage`, `read` and `write` the connector index (`.elastic-connectors`), the connector job index (`.elastic-connectors-sync-jobs`) and the connector content indices (`search-*`).
3. Run the connector service with
    ```shell
    make run
    ```

### Run the connector service for a custom connector

Refer to [Test your connector](./DEVELOPING.md#test-your-connector) for detailed explanation.
