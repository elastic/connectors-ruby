#!/bin/bash

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

set -ex

export HOME=$JENKINS_HOME

# set up rbenv
export RBENV_VERSION="2.5.5"
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# get the right jruby
export JRUBY_VERSION="$(cat .ruby-version)"
rbenv shell "$RUBY_VERSION"
rbenv rehash

# get the right java
export JAVA_HOME=$HOME/.java/java11

# run the build
./mvnw clean verify