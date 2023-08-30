#!/bin/bash

set -euxo pipefail

COMMAND_TO_RUN=${1:-}

if [[ "${COMMAND_TO_RUN:-}" == "" ]]; then
    echo "Usage: run_pipline_command {tests|linter|docker|packaging}"
    exit 2
fi

function realpath {
  echo "$(cd "$(dirname "$1")"; pwd)"/"$(basename "$1")";
}

SCRIPT_WORKING_DIR=$(realpath "$(dirname "$0")")
BUILDKITE_DIR=$(realpath "$(dirname "$SCRIPT_WORKING_DIR")")
PROJECT_ROOT=$(realpath "$(dirname "$BUILDKITE_DIR")")
SHARED_SCRIPT_DIR="${SCRIPT_WORKING_DIR}/shared"

source "${SHARED_SCRIPT_DIR}/pull_shared_scripts.sh"
source "${SHARED_SCRIPT_DIR}/docker-retry.sh"
source "${SHARED_SCRIPT_DIR}/run_docker_ci_script.sh"

DOCKER_IMAGE="docker.elastic.co/ci-agent-images/enterprise-search/rbenv-buildkite-agent:latest"
SCRIPT_CMD=".buildkite/scripts/run_command.sh ${COMMAND_TO_RUN}"
ENV_VARS=("GIT_REVISION=${BUILDKITE_COMMIT-}" "BUILD_ID=${BUILDKITE_BUILD_NUMBER-}" "setuser:root")

runDockerCIScript "${DOCKER_IMAGE}" "${SCRIPT_CMD}" "${ENV_VARS[@]}"
