# Connectors Developer's Guide

So you want to modify some connectors code? Well, you've come to the right place!

After you've made your changes, if you'd like to contribute back, please see the [contributing guide](./CONTRIBUTING.md).

### Requirements
- rbenv (see [rbenv installation](https://github.com/rbenv/rbenv#installation))
- bundler (for version, see [.bundler-version](./.bundler-version))
- yq (see [yq installation](https://github.com/mikefarah/yq#install))

### Setup
1. Fork this repository

### Installing dependencies

From the root level of this repository:

```shell
make install
```

### Building

The repository can generate ruby gems (connectors service itself or shared connectors service library), if needed.

Generate Connector Service gem:
```shell
make build_service_gem
```

Generate shared Connector Services libraries gem:
````shell
make build_utility_gem
````

### Testing
```shell
# ensure code standards
make lint

# run unit tests
make test
```

### Code Organization

Each connector has its own dedicated directory under `lib/connectors`. Connectors are hierarchical, so you may find that much of the underlying code for any given connector lives in `lib/connectors/base/**/*.rb`, rather than in the specific connector's implementation.

Shared utilities, constants, error classes, etc live under `lib/utility`.

The connectors server and its helpers live under `lib/app`.

Finally, you may notice a `lib/stubs` directory. This is a holdover from migrating from Enterprise Search's monolithic codebase, and these files should eventually be refactored away.

All tests in the repo live under `spec`, and should match the path of the file/class that they test. For example a `lib/foo/bar.rb` should have a corresponding `spec/foo/bar_spec.rb` test file.

### IDE and Debugging

This project is fairly simple and conventional as a bundler-based Ruby project, so any popular IDE with ruby support should work fine. The maintaining team uses several IDEs including Intellij, RubyMine, Sublime, and VSCode.

Debugging varies from IDE to IDE, but the gems `ruby-debug-ide`, `pry-remote`, `pry-nav`, and `debase` are all included in the Gemfile, and should be sufficient to power your debugging.

In addition, you can spin up a local interactive REPL using
```shell
make console
```
