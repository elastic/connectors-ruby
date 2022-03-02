all: install credentials run

test:
	bundle exec rspec spec

lint:
	bundle exec rubocop lib spec

autocorrect:
	bundle exec rubocop lib spec -a

build:
	git rev-parse HEAD > lib/.revision
	mkdir -p .gems
	gem build connectors_shared.gemspec
	mv *.gem .gems/

install:
	rbenv install -s
	- gem install bundler -v 2.2.33
	bundle install --jobs 1

credentials:
	vaulter read ws-google-drive-service-account --json > ent-search-dev.json

run:
	cd lib/app; bundle exec rackup config.ru
