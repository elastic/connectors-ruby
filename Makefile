all: install credentials run

test:
	bundle exec rspec spec

build:
	mkdir -p .gems
	gem build ent-search-connectors.gemspec -o .gems/ent-search-connectors-0.0.1.gem

install:
	- gem install bundler -v 2.2.29
	bundle config set --local path 'vendor/bundle'
	bundle install

credentials:
	vaulter read ws-google-drive-service-account --json > ent-search-dev.json

run:
	cd lib/app; bundle exec rackup config.ru
