#!/bin/bash
set -ex

BUILD_DIR=$1
SOURCE_DIR=$2
MODULE_NAME=$3

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
TARGET_DIR="./$MODULE_NAME/src/main"
mkdir -p "$TARGET_DIR"
cp -r "$SOURCE_DIR" "$TARGET_DIR"

jrubyc --javac -v .