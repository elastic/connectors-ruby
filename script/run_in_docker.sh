#!/bin/bash

DIR="$(dirname "${BASH_SOURCE[0]}")"
DIR="$(realpath "${DIR}")"

echo $DIR


for var in `compgen -v`
do
	export $var
done

cd $DIR/../lib/app
rbenv exec bundle exec ruby app.rb
