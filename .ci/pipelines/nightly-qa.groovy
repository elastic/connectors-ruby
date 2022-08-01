// import apm-pipeline-library to get their overriden 'checkout' step, which
// gives us some timeouts and sleeps that we currently need to deal with some
// network connectivity problems; see for more info:
//   https://github.com/elastic/infra/issues/16573#issuecomment-577848001
@Library('apm') _

def NODE_LABEL = 'linux && immutable'

def GITHUB_ORG = 'elastic'
def GIT_REPO = 'ent-search'
def GIT_CREDENTIALS = '2a9602aa-ab9f-4e52-baf3-b71ca88469c7-UserAndToken'  // elasticmachine
def GIT_REFERENCE_REPO = '/var/lib/jenkins/.git-references/ent-search.git'

def withRbenv(Closure block) {
    print "Enabling rbenv support at ${env.JENKINS_HOME}/.rbenv"

    withEnv(["PATH=${env.JENKINS_HOME}/.rbenv/shims:${env.JENKINS_HOME}/.rbenv/bin:${env.PATH}"]) {
        block()
    }
}

// -----------------------------------------------------------------------------

pipeline {
    agent {
        label(NODE_LABEL)
    }

    options {
        ansiColor('xterm')

        buildDiscarder(
            logRotator(
                artifactDaysToKeepStr: '',
                artifactNumToKeepStr: '',
                daysToKeepStr: '7',
                numToKeepStr: '',
            )
        )

        disableResume()
        durabilityHint('PERFORMANCE_OPTIMIZED')
        skipDefaultCheckout()
        timeout(time: 2, unit: 'HOURS')
        timestamps()
    }

    parameters {
        string(
            name: 'VAULT_TOKEN',
            defaultValue: '',
            description: 'Auth token to Vault that can be used to fetch secrets'
        )
        string(
            name: 'BRANCH',
            defaultValue: 'main',
            description: 'Branch used to run the e2e test'
        )
    }

    environment {
        VAULT_TOKEN = "${params.VAULT_TOKEN}"
        VAULT_ROLE_ID = credentials('vault-role-id')
        VAULT_SECRET_ID = credentials('vault-secret-id')
        HOME = "${env.JENKINS_HOME}"
        VAULT_ADDR = credentials('vault-addr')
    }

    stages {
        stage('Setup') {
            steps {
                gitCheckout(
                    repo: "git@github.com:${GITHUB_ORG}/${GIT_REPO}.git",
                    branch: "${params.BRANCH}",
                    credentialsId: "${GIT_CREDENTIALS}",
                    basedir: 'app',
                    reference: "${GIT_REFERENCE_REPO}",
                    shallow: true,
                    depth: 20,
                    noTags: true
                )
            }
        }

        stage('Run Mongo test') {
            steps {
                dir('app') {
                    withRbenv {
                        sh 'make ftest'
                    }
                }
            }
        }
    }
}
