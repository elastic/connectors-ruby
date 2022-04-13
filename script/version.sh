#!/bin/bash
set -e

prefix=`cat VERSION` # Retrieve the version prefix
timestamp=`date -u +%Y%m%dT%H%M%SZ` # Calculate the current ISO8601 format UTC timestamp
version="${prefix}-${timestamp}" # concatenate the prefix with the timestamp

echo $version
