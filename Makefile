all: install credentials run

test:
	bundle exec rspec spec

build:
	mkdir -p .gems
	gem build connectors_shared.gemspec
	mv *.gem .gems/

install:
	- gem install bundler -v 2.2.29
	bundle config set --local path 'vendor/bundle'
	bundle install

credentials:
	vaulter read ws-google-drive-service-account --json > ent-search-dev.json

run:
	cd lib/app; bundle exec rackup config.ru
