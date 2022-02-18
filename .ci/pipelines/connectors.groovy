/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

// Loading the shared lib
@Library(['estc', 'entsearch']) _

eshPipeline(
    timeout: 45,
    project_name: 'Connectors',
    repository: 'connectors',
    stage_name: 'Connectors Unit Tests',
    [
        name: 'Tests',
        type: 'script',
        label: 'Makefile',
        script: {
            sh 'make test'
        },
        match_on_all_branches: true,
    ],
    [
        name: 'Packaging',
        type: 'script',
        label: 'Makefile',
        script: {
            sh 'make build'
        }
    ]
    slack_channel: 'workplace-search-connectors'
)
