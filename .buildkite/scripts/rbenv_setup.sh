#!/bin/bash

set -euxo pipefail

curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
eval "$(~/.rbenv/bin/rbenv init - bash)"
eval "$(~/.rbenv/bin/rbenv install $(cat .ruby-version))"
eval "$(~/.rbenv/bin/rbenv global $(cat .ruby-version))"
