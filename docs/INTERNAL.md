# Elastic Internal Documentation

### Copying artifacts to Enterprise Search

1. run `make build`
1. cd to your ent-search checkout
1. run  `gem uninstall connectors_sdk`
1. copy the artifacts in the `.gems` directory to the `vendor/cache` directory in Enterprise Search repository.
1. run `script/bundle install`
