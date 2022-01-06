#!/bin/bash

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

set -ex

BUILD_DIR=$1
SOURCE_DIR=$2
MODULE_NAME=$3

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
TARGET_DIR="./$MODULE_NAME/src/main"
mkdir -p "$TARGET_DIR"
cp -r "$SOURCE_DIR" "$TARGET_DIR"

jrubyc --java -v .