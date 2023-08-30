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

DOCKER_IMAGE="docker.elastic.co/ci-agent-images/enterprise-search/rbenv-buildkite-agent:latest"
SCRIPT_CMD=".buildkite/scripts/run_command.sh ${COMMAND_TO_RUN}"

docker run --interactive --rm             \
             --sig-proxy=true --init      \
             --user "root"                \
             --volume "$PROJECT_ROOT:/ci" \
             --workdir /ci                \
             --env HOME=/ci               \
             --env REVISION               \
             --env CI                     \
             --env GIT_REVISION=${BUILDKITE_COMMIT-}   \
             --env BUILD_ID=${BUILDKITE_BUILD_NUMBER-} \
             --entrypoint "/bin/bash ${SCRIPT_CMD}"    \
             $DOCKER_IMAGE
