#!/bin/bash

# Start the connectors HTTP service
make run &

# Start the Elastic Enterprise Search app
/usr/local/bin/docker-entrypoint.sh &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
