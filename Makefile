YQ ?= "yq"
.phony: test lint autocorrect update_config
.phony: install build-docker run-docker exec_app tag

config/connectors.yml:
	cp config/connectors.yml.example config/connectors.yml

test: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rspec spec --order rand

lint: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rubocop lib spec

autocorrect: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rubocop lib spec -a

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

tag:
	git tag v$(shell cat VERSION)
	git push --tags

install:
	rbenv install -s
	- gem install bundler -v $(shell cat .bundler-version) && rbenv rehash
	bundle _$(shell cat .bundler-version)_ install --jobs 1

build-docker:
	docker build -t connectors .

run-docker:
	docker run --rm -it -p 127.0.0.1:9292:9292/tcp connectors

exec_app:
	cd lib/app; bundle _$(shell cat .bundler-version)_ exec ruby console_app.rb

run: | update_config_dev exec_app
