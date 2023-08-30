#!/bin/bash

set -euxo pipefail

export PATH="$PATH:/root/.rbenv/bin:/root/.rbenv/plugins/ruby-build/bin:/ci/.rbenv/shims"

RUBY_VERSION=$(cat .ruby-version)
echo "---- installing Ruby version $RUBY_VERSION"
rbenv install $RUBY_VERSION
rbenv global $RUBY_VERSION

case $1 in

  tests)
    echo "---- running unit tests"
    make install test
    ;;

  linter)
    echo "---- running linter"
    make install lint
    ;;

  packaging)
    echo "---- running packaging"
    curl -L -o yq https://github.com/mikefarah/yq/releases/download/v4.21.1/yq_linux_amd64
    chmod +x yq
    YQ=`realpath yq` make install build_service build_service_gem
    gem install .gems/connectors_service-8.*
    ;;

  *)
    echo "Usage: run_command {tests|linter|packaging}"
    exit 2
    ;;
esac
