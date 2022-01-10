#!/bin/bash

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

set -ex

export JRUBY_VERSION="$(cat .ruby-version)"
rbenv shell "$RUBY_VERSION"
rbenv rehash

export JAVA_HOME=$JENKINS_HOME/.java/java11

./mvnw clean verify