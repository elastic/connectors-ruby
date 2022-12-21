YQ ?= "yq"
.phony: test ftest lint autocorrect update_config autocorrect-unsafe install build-docker run-docker exec_app tag exec_cli
.phony: build_utility build_service release_utility_dev release_service_dev release_utility release_service build_utility_gem build_service_gem

config/connectors.yml:
	cp config/connectors.yml.example config/connectors.yml

test: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rspec spec --order rand

ftest:
	-cp config/connectors.yml config/connectors.yml.$$(date +%Y%m%d%H%M%S).saved 2>/dev/null
	cp tests/connectors.yml config/connectors.yml
	rbenv exec bundle exec ruby tests/ftest.rb

lint: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rubocop lib spec

autocorrect: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rubocop lib spec -a

autocorrect-unsafe: config/connectors.yml
	bundle _$(shell cat .bundler-version)_ exec rubocop lib spec -A

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

build_utility: update_config_dev build_utility_gem

build_service: update_config_dev build_service_gem

release_utility: update_config build_utility_gem push_gem tag

release_service: update_config build_service_gem push_gem tag

release_utility_dev: update_config_dev build_utility_gem push_gem

release_service_dev: update_config_dev build_service_gem push_gem

tag:
	git tag v$(shell cat VERSION)
	git push --tags

build_utility_gem:
	mkdir -p .gems
	bundle _$(shell cat .bundler-version)_ exec gem build connectors_utility.gemspec
	rm -f .gems/*
	mv *.gem .gems/
	echo "DO NOT FORGET TO UPDATE ENT-SEARCH"

build_service_gem:
	mkdir -p .gems
	bundle _$(shell cat .bundler-version)_ exec gem build connectors_service.gemspec
	rm -f .gems/*
	mv *.gem .gems/

push_gem:
	bundle _$(shell cat .bundler-version)_ exec gem push .gems/*

install:
	rbenv install -s
	- gem install bundler -v $(shell cat .bundler-version) && rbenv rehash
	bundle _$(shell cat .bundler-version)_ install --jobs 1

install_for_production:
	- gem install bundler -v $(shell cat .bundler-version) && rbenv rehash
	bundle _$(shell cat .bundler-version)_ install --without development test --jobs 1

build-docker:
	docker build -t connectors .

run-docker:
	docker run --env "elasticsearch.hosts=http://host.docker.internal:9200" --env "elasticsearch.api_key=$(API_KEY)" --rm -it connectors

exec_app:
	cd lib/app; bundle _$(shell cat .bundler-version)_ exec ruby app.rb

run_producer:
	cd lib/app; bundle _$(shell cat .bundler-version)_ exec ruby producer_app.rb

run_consumers:
	cd lib/app; bundle _$(shell cat .bundler-version)_ exec ruby consumer_app.rb

exec_cli:
	cd lib/app; bundle _$(shell cat .bundler-version)_ exec ruby console_app.rb

run: | update_config_dev exec_app
