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
                  if (isUnix()) {
                    sh('make install test')
                  } else {
                    bat('win32\\install.bat')
                    bat('make.bat')
                  }
                }
                publishHTML (target: [
                    allowMissing: true,
                    alwaysLinkToLastBuild: false,
                    keepAll: true,
                    reportDir: 'coverage',
                    reportFiles: 'index.html',
                    reportName: 'Coverage Report'
                ])
            },
            // nodes: ['linux', 'windows'], // disabled pending https://github.com/elastic/ent-search-jenkins-lib/pull/36
            match_on_all_branches: true,
       ],
       [
            name: 'Linter',
            type: 'script',
            script: {
                eshWithRbenv {
                  sh('make install lint')
                }
            },
            match_on_all_branches: true,
       ],
       [
            name: 'Docker',
            type: 'script',
            script: {
                eshWithRbenv {
                  sh('make build-docker')
                }
            },
            match_on_all_branches: true,
       ]
    ],
    slack_channel: 'ent-search-ingestion'
)
