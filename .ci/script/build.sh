#!/bin/bash

#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

set -ex

export HOME=$JENKINS_HOME

# get the right java
export JAVA_HOME=$HOME/.java/java11

# set up rbenv
export RBENV_VERSION="2.5.5"
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# get the right jruby
export JRUBY_VERSION="$(cat .ruby-version)"
export RUBY_VERSION=$JRUBY_VERSION
rbenv install --skip-existing "$JRUBY_VERSION"
rbenv shell "$JRUBY_VERSION"
rbenv rehash
rbenv versions
rbenv global $JRUBY_VERSION
ruby --version # just to double-check...
which -a ruby
ruby_bin_file=$(which ruby)
export BUNDLE_CMD="$ruby_bin_file -S bundle"
export GEM_CMD="$ruby_bin_file -S gem"
export BUNDLE_GEMFILE="$(pwd)/Gemfile"

# install bundler
$GEM_CMD install bundler:2.2.29

# install gems
$BUNDLE_CMD install

# run the build
./mvnw clean verify
