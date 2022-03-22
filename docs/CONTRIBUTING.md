# Connectors Contributor's Guide

Thank you for your interest in contributing to Connectors!

You may also want to read the [development guide](./DEVELOPING.md).

### Before you start

* Prior to opening a pull request, please:
    * Read the entirety of this document
    * [Create an issue](https://github.com/elastic/connectors/issues) to discuss the scope of your proposal.
    * Sign the [Contributor License Agreement](https://www.elastic.co/contributor-agreement/). We are not asking you to
      assign copyright to us, but to give us the right to distribute your code without restriction. We ask this of all
      contributors in order to assure our users of the origin and continuing existence of the code. You only need to 
      sign the CLA once.
    * Run all tests locally, and ensure they are all passing  
* Please write simple code and concise documentation, when appropriate.


### Testing

It is expected that any contribution will include unit tests. The linter and all unit tests must be passing in order to merge any pull request. Ensure that your tests are passing locally _before_ submitting a pull request.

```shell
# ensure code standards
make lint

# run unit tests
make test
```

### Branching Strategy

Our `main` branch holds the latest development code for the next release. If the next release will be a minor release,
the expecation is that no breaking changes will be in `main`. If a change would be breaking, we need to put it behind a
feature flag, or make it an opt-in change. We will only merge breaking PRs when we are ready to start working on the
next major.

All PRs should be created from a fork, to keep a clean set of branches on `origin`.

Releases will be performed directly in `main` (or a minor branch for patches).

We will create branches for all minor releases.
