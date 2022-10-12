# Releasing the Connectors project

The version scheme we use is **MAJOR.MINOR.PATCH.BUILD** and stored in the [VERSION](https://github.com/elastic/connectors-ruby/blob/main/VERSION) file
at the root of this repository.

## Unified release

**MAJOR.MINOR.PATCH** should match the Elastic and Enterprise Search version it targets
and the *BUILD* number should be set to **0** the day the Connectors release is created
to be included with the Enterprise Search distribution.

For example, when shipping for `8.1.2`, the version is `8.1.2.0`.

To release Connectors into Cloud Enterprise Search image:

- Set the VERSION file to the new/incremented version on the release branch
- Make sure all tests and linter pass with `make lint test`
- PR these changes to the appropriate Connectors release branch
- Run `make update_config` so that correct version is put into the configuration file
- Run `make build_utility_gem` and copy the gem from `./.gems` into `ent-search` directory `./vendor/cache`
- Update the version of gem in `ent-search` Gemfile, run `script/bundle install`.
- Run `make build_service_gem` and copy the gem from `./gems` into `ent-search` directory `dist/shared/cloud/coservices`.
- Update the version in `ent-search` file `./dist/shared/cloud/coservices/ruby-connectors.yml` to point to the newly released version
- Commit all changes in `ent-search` to a new branch and push it. After the branch is tested, create a PR in `ent-search` that includes your changes to finish the release.

After the Elastic unified release is complete

- Update the **BUILD** version ([example PR](https://github.com/elastic/connectors-ruby/pull/81)). Note that the Connectors project does not immediately bump to the next **PATCH** version. That wont happen until that patch release's FF date.


## Testing the changes
Once the release steps are finished and the branch is created for `ent-search` that contains new gem versions, you need to wait for `packaging` job to finish. Once it's finished, you can grab the docker image built by Jenkins. To do so navigate to https://swiftype-ci.elastic.co/job/ent-search/job/packaging/ and find the packaging job for your PR. There download `enterprise-search-cloud-docker-image-{VERSION}-SNAPSHOT.tar.gz` and run it in local docker to verify that your changes did not break anything - you can run a native MongoDB/MySQL connectors or Crawler inside Enterprise Search to do the tests. 

## In-Between releases

Sometimes, we need to release Connectors independantly from Enterprise Search.
For instance, if someone wants to use the project as an HTTP Service and we have a
bug fix we want them to have as soon as possible.

In that case, we increment the **BUILD** number, and follow the same release
process than for the unified release.

So `8.1.2.1`, `8.1.2.2` etc. On the next unified release, the version will be bumped to
the next **PATCH** value, and **BUILD** set to `0`

**In-Between releases should never introduce new features since they will eventually be
merged into the next PATCH release. New features are always done in Developer previews**

## Developer preview releases

For developer previews, we are adding a `pre` tag using an ISO8601 date.
You can use `make release_dev` instead of `make release` in that case.
