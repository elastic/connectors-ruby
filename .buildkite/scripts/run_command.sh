#!/bin/bash

set -euxo pipefail

export PATH="$PATH:~/.rbenv/bin"

rbenv install $(cat .ruby-version)
rbenv global $(cat .ruby-version)

COMMAND_TO_RUN=${1-}

case COMMAND_TO_RUN in

  tests)
    echo "running unit tests"
    make install test
    ;;

  linter)
    echo "running linter"
    make install lint
    ;;

  docker)
    echo "running docker build"
    make build-docker
    ;;

  packaging)
    echo "running packaging"
    curl -L -o yq https://github.com/mikefarah/yq/releases/download/v4.21.1/yq_linux_amd64
    chmod +x yq
    YQ=`realpath yq` make install build_service build_service_gem
    gem install .gems/connectors_service-8.*
    ;;

  *)
    echo "Usage: run_command {tests|linter|docker|packaging}"
    ;;
esac
