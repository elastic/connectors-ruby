YQ ?= "yq"
.phony: test lint autocorrect api_key update_config build 
.phony: release_dev release build_gem install refresh_config build-docker run-docker exec_app tag

config/connectors.yml:
	cp config/connectors.yml.example config/connectors.yml

test: config/connectors.yml
	bundle exec rspec spec

lint: config/connectors.yml
	bundle exec rubocop lib spec

autocorrect: config/connectors.yml
	bundle exec rubocop lib spec -a

api_key: config/connectors.yml
	${YQ} e ".http.api_key = \"$(shell uuidgen | tr -d '-')\"" -i config/connectors.yml

# build will set the revision key in the config we use in the Gem
# we can add more build=time info there if we want
update_config_dev: config/connectors.yml
	${YQ} e ".revision = \"$(shell git rev-parse HEAD)\"" -i config/connectors.yml
	${YQ} e ".repository = \"$(shell git config --get remote.origin.url)\"" -i config/connectors.yml
	${YQ} e ".version = \"$(shell script/version.sh)\"" -i config/connectors.yml

update_config: config/connectors.yml
	${YQ} e ".revision = \"$(shell git rev-parse HEAD)\"" -i config/connectors.yml
	${YQ} e ".repository = \"$(shell git config --get remote.origin.url)\"" -i config/connectors.yml
	${YQ} e ".version = \"$(shell cat VERSION)\"" -i config/connectors.yml

build: update_config_dev build_gem

release: update_config build_gem push_gem tag

release_dev: update_config_dev build_gem push_gem

tag:
	git tag v$(shell cat VERSION)
	git push --tags

build_gem:
	mkdir -p .gems
	gem build connectors_sdk.gemspec
	rm -f .gems/*
	mv *.gem .gems/
	echo "DO NOT FORGET TO UPDATE ENT-SEARCH"

push_gem:
	gem push .gems/*

install:
	rbenv install -s
	- gem install bundler -v 2.2.33 && rbenv rehash
	bundle install --jobs 1

refresh_config: update_config
	cd lib/app; bundle exec rackup --host 0.0.0.0 config.ru

build-docker:
	docker build -t connectors .

run-docker:
	docker run --rm -it -p 127.0.0.1:9292:9292/tcp connectors

exec_app:
	cd lib/app; bundle exec rackup config.ru

run: | refresh_config exec_app

console:
	cd lib/app; bundle exec irb -r ./console.rb
