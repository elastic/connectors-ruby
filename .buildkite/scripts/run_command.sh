#!/bin/bash

set -euxo pipefail

export PATH="$PATH:~/.rbenv/bin"

function install_ruby_version() {
    local ruby_version=$(cat .ruby-version)
    curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
    echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
    rbenv install $ruby_version
    rbenv global $ruby_version
}

case $1 in

  tests)
    echo "running unit tests"
    install_ruby_version
    make install test
    ;;

  linter)
    echo "running linter"
    install_ruby_version
    make install lint
    ;;

  docker)
    echo "running docker build"
    # install_ruby_version
    # install_docker
    make build-docker
    ;;

  packaging)
    echo "running packaging"
    install_ruby_version
    curl -L -o yq https://github.com/mikefarah/yq/releases/download/v4.21.1/yq_linux_amd64
    chmod +x yq
    YQ=`realpath yq` make install build_service build_service_gem
    gem install .gems/connectors_service-8.*
    ;;

  *)
    echo "Usage: run_command {tests|linter|docker|packaging}"
    ;;
esac
