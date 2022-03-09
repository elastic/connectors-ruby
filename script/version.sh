#!/bin/bash
set -e

prefix=`cat VERSION` # Retrieve the version prefix
timestamp=`date +%s` # Calculate the current timestamp

version="${prefix}-${timestamp}" # concatenate the prefix with the timestamp

echo $version
