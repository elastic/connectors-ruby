#!/bin/bash

set -euxo pipefail

curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
ln -s ~/.rbenv/versions/multiruby-mri-"$(cat .ruby-version)" ~/.rbenv/versions/"$(cat .ruby-version)"
