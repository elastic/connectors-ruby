/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

// Loading the shared lib
@Library(['apm', 'estc', 'entsearch']) _

eshPipeline(
    timeout: 45,
    project_name: 'Connectors',
    repository: 'connectors',
    stage_name: 'Connectors Unit Tests',
    stages: [
       [
            name: 'Tests',
            type: 'script',
            script: {
                eshWithRbenv {
                  sh 'make install test'
                }
            },
            match_on_all_branches: true,
       ],
       [
           name: 'Packaging',
           type: 'script',
           script: {
               eshWithRbenv {
                 sh 'make install build'
               }
           },
           artifacts: [[pattern: 'app/.gems/*.gem']],
           match_on_all_branches: true,
       ]
    ],
    slack_channel: 'workplace-search-connectors'
)
