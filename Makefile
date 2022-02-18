all: install build_java_artifacts credentials run

install:
	bundle config set --local path 'vendor/bundle'
	bundle install

build_java_artifacts:
	./mvnw clean install

credentials:
	vaulter read ws-google-drive-service-account --json > http/ent-search-dev.json

run:
	cd http; bundle exec rackup config.ru
gem_version = 0.0.1

test:
	rspec connectors/spec

build:
	mkdir -p .gems
	gem build connectors.gemspec -o .gems/connectors-${gem_version}.gem
