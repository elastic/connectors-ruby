YQ ?= "yq"

test:
	bundle exec rspec spec

lint:
	bundle exec rubocop lib spec

autocorrect:
	bundle exec rubocop lib spec -a

api_key:
	${YQ} e ".http.api_key = \"$(shell uuidgen | tr -d '-')\"" -i config/connectors.yml

# build will set the revision key in the config we use in the Gem
# we can add more build=time info there if we want
build:
	${YQ} e ".revision = \"$(shell git rev-parse HEAD)\"" -i config/connectors.yml
	${YQ} e ".repository = \"$(shell git config --get remote.origin.url)\"" -i config/connectors.yml
	${YQ} e ".version = \"$(shell script/version.sh)\"" -i config/connectors.yml
	mkdir -p .gems
	gem build connectors_sdk.gemspec
	rm -f .gems/*
	mv *.gem .gems/

install:
	rbenv install -s
	- gem install bundler -v 2.2.33
	bundle install --jobs 1
	cp -n config/connectors.yml.example config/connectors.yml || true

run:
	${YQ} e ".revision = \"$(shell git rev-parse HEAD)\"" -i config/connectors.yml
	${YQ} e ".repository = \"$(shell git config --get remote.origin.url)\"" -i config/connectors.yml
	${YQ} e ".version = \"$(shell script/version.sh)\"" -i config/connectors.yml
	cd lib/app; bundle exec rackup config.ru

console:
	cd lib/app; bundle exec irb -r ./console.rb
