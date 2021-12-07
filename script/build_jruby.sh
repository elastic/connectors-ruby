#!/bin/bash
set -ex

BUILD_DIR=$1
SOURCE_DIR=$2

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cp -r "$SOURCE_DIR" .

jrubyc --javac -v "$BUILD_DIR"