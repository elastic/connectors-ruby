#!/bin/bash
set -e

prefix=`cat VERSION` # Retrieve the version prefix
timestamp=`date +%Y%m%d%H%M%S` # Calculate the current timestamp in ISO8601 format

version="${prefix}-${timestamp}" # concatenate the prefix with the timestamp

echo $version
