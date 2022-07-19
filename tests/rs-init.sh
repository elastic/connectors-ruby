#!/bin/bash

mongosh <<EOF
var config = { };
rs.initiate(config, { force: true });
rs.status();
EOF
