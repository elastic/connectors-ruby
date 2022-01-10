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
    stages: [
        [
            name: 'Maven Build',
            type: 'script',
            label: 'Maven Build',
            script: {
                withMaven {
                    sh 'JAVA_HOME=$JENKINS_HOME/.java/java11 ./mvnw clean verify'
                }
            },
            match_on_all_branches: true,
        ]
    ],
    slack_channel: 'workplace-search-connectors'
)