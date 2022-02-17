.phony: install build_java_artifacts credentials run

install:
	bundle config set --local path 'vendor/bundle'
	bundle install

build_java_artifacts:
	./mvnw clean install

credentials:
	vaulter read ws-google-drive-service-account --json > http/ent-search-dev.json

run:
	cd http; bundle exec rackup config.ru
