#!/bin/bash

set -euxo pipefail

eval "$(~/.rbenv/bin/rbenv install $(cat .ruby-version))"
eval "$(~/.rbenv/bin/rbenv global $(cat .ruby-version))"
