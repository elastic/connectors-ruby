#!/bin/bash

set -euxo pipefail

rbenv install $(cat .ruby-version)
rbenv global $(cat .ruby-version)
