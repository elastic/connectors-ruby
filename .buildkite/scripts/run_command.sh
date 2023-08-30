#!/bin/bash

set -euxo pipefail

export PATH="$PATH:~/.rbenv/bin"

function install_ruby_version() {
    local ruby_version=$(cat .ruby-version)
    rbenv install $ruby_version
    rbenv global $ruby_version
}

function install_docker() {
    # apt-cache madison docker-ce | awk '{ print $3 }'

    # curl -fsSL https://get.docker.com | sh
    #apt update && apt install docker.io -y

    #apt-get update
    #apt-get install -y gnupg
    #install -m 0755 -d /etc/apt/keyrings
    #curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    #chmod a+r /etc/apt/keyrings/docker.gpg#

    #echo \
    #    "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    #    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    #    tee /etc/apt/sources.list.d/docker.list > /dev/null

    #apt-get update
    #apt-get install -y \
    #    docker-ce docker-ce-cli containerd.io \
    #    docker-buildx-plugin docker-compose-plugin
    #service docker start
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
    install_docker
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
