#!/bin/bash

set -euo pipefail

if [[ "${PROJECT_ROOT:-}" == "" ]]; then
  echo "ERROR: PROJECT_ROOT is not set."
  exit 2
fi

SHARED_SCRIPTS_DIR="$(dirname "${BASH_SOURCE}")"

# clone the repo into a temp directory
TMP_CLONE_DIR="${PROJECT_ROOT}/tmp_ci-build"
mkdir -p "$TMP_CLONE_DIR"

pushd "$TMP_CLONE_DIR"

git clone git@github.com:elastic/ent-search-ci-build.git
CLONED_SHARED_SCRIPTS="$TMP_CLONE_DIR/ent-search-ci-build/shared_scripts"
cp -rf $CLONED_SHARED_SCRIPTS/* $SHARED_SCRIPTS_DIR/

popd

# and if we don't need the cloned directory...
rm -rf "$TMP_CLONE_DIR"
