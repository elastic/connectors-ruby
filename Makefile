YQ ?= "yq"

all: install credentials run

test:
	bundle exec rspec spec

lint:
	bundle exec rubocop lib spec

autocorrect:
	bundle exec rubocop lib spec -a


# build will set the revision key in the config we use in the Gem
# we can add more build=time info there if we want
build:
	cp config/connectors.yml .saved
	${YQ} e ".revision = \"$(shell git rev-parse HEAD)\"" -i config/connectors.yml
	mkdir -p .gems
	gem build connectors_shared.gemspec
	mv *.gem .gems/
	mv .saved config/connectors.yml

install:
	rbenv install -s
	- gem install bundler -v 2.2.33
	bundle install --jobs 1

credentials:
	vaulter read ws-google-drive-service-account --json > ent-search-dev.json

run:
	cd lib/app; bundle exec rackup config.ru
