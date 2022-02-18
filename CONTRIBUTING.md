# Connectors Contributor's Guide

Thank you for your interest in contributing to Connectors!

How to build and contribute to Connectors.

### Requirements

- JRuby
- OS: Unix/Linux

### Installing dependencies

From the root level of this repository:

```shell
make install
```

### Building

The repository can generate a ruby gem, if needed.

```shell
# Build
make build
```

### Testing

```shell
make test
```

It is expected that any contribution will include unit tests. Tests must be passing in order to merge any pull request.

### Branching Strategy

Our `main` branch holds the latest development code for the next release. If the next release will be a minor release,
the expecation is that no breaking changes will be in `main`. If a change would be breaking, we need to put it behind a
feature flag, or make it an opt-in change. We will only merge breaking PRs when we are ready to start working on the
next major.

All PRs should be created from a fork, to keep a clean set of branches on `origin`.

Releases should be performed directly in `main` (or a minor branch for patches), following the Publishing guide below.

We will create branches for all minor releases.

### Publishing

##### Publish a new major or minor from `main`
(Example, publishing 1.1.0)

1. Manually [deploy a snapshot](https://internal-ci.elastic.co/job/elastic+connectors+deploy-snapshot/) from `main` to ensure that there are no issues with the deploy mechanisms.
2. Verify the snapshots are in [https://oss.sonatype.org/content/repositories/snapshots/co/elastic/connectors/](https://oss.sonatype.org/content/repositories/snapshots/co/elastic/connectors/)
3. Create a new minor release branch, like `git checkout -b 1.1`
4. Push the new minor release branch to the origin, like `git push origin 1.1`
5. Go back to the `main` branch, like `git checkout main`
6. Update the `main` branch to point at the next version, like `mvn versions:set -DnewVersion=1.2.0-SNAPSHOT`
7. Verify your local changes, commit, and push.
8. Manually [trigger a release](https://internal-ci.elastic.co/job/elastic+connectors+release/) from the new minor release branch (`1.1` in this example).
9. Even after the build goes green, artifacts may take 30 minutes or so to appear in [https://repo1.maven.org/maven2/co/elastic/connectors](https://repo1.maven.org/maven2/co/elastic/connectors)
10. In the mean time, verify the automatic (or manually deploy) [snapshot builds](https://internal-ci.elastic.co/job/elastic+connectors+deploy-snapshot/) for the new minor patch SNAPSHOT (`1.1.1-SNAPSHOT` in this example) and the new main SNAPSHOT (`1.2.0-SNAPSHOT` in this example)
11. Once the release artifacts are available from Maven Central, [create a new Github Release](https://github.com/elastic/connectors/releases/new) from the new tag and artifacts.

##### Publish a patch
(Example, publish 1.0.1)

1. Manually [deploy a snapshot](https://internal-ci.elastic.co/job/elastic+connectors+deploy-snapshot/) from the release branch (`1.0` in this example) to ensure that there are no issues with the deploy mechanisms.
2. Verify the snapshots are in [https://oss.sonatype.org/content/repositories/snapshots/co/elastic/connectors/](https://oss.sonatype.org/content/repositories/snapshots/co/elastic/connectors/)
3. Manually [trigger a release](https://internal-ci.elastic.co/job/elastic+connectors+release/) from the minor release branch (`1.0` in this example).
4. Even after the build goes green, artifacts may take 30 minutes or so to appear in [https://repo1.maven.org/maven2/co/elastic/connectors](https://repo1.maven.org/maven2/co/elastic/connectors)
5. In the mean time, verify the automatic (or manually deploy) [snapshot build](https://internal-ci.elastic.co/job/elastic+connectors+deploy-snapshot/) for the new patch SNAPSHOT (`1.0.2-SNAPSHOT` in this example)
6. Once the release artifacts are available from Maven Central, [create a new Github Release](https://github.com/elastic/connectors/releases/new) from the new tag and artifacts.
