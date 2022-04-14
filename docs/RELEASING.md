# Releasing the Connectors project

The Connectors project is packaged as a Gem that is added in the Enterprise Search distribution.

The version scheme we use is **MAJOR.MINOR.PATCH.BUILD** and stored in the [VERSION](VERSION) file
at the root of this repository.

## RubyGem Account

When releasing Gems, you will be asked for an Email and Password.
Look into the Vault in the `ent-search-team/rubygem` secret.


## Unified release

**MAJOR.MINOR.PATCH** should match the Elastic and Enterprise Search version it targets 
and the *BUILD* number should be set to **0** the day the release is created
to be included with the Enterprise Search distribution.

For example, when shipping for `8.1.2`, the version is `8.1.2.0`.

To release Connectors:

- set the VERSION file to the right version
- make sure all tests and linter pass with `make lint test`
- run `make release`

A Gem file will be created in the `.gem` directory, that needs to be embed in Enterprise Search.

Immediately update ent-search's gem dependency with the released version:

- update the Gem in vendor/cache
- update Gemfile

Last, take care of the branching:

- Increment the VERSION on main to match the next release
- create a new maintenance branch if it's a new MINOR


## In-Between releases

Sometimes, we need to release Connectors independantly from Enterprise Search.
For instance, if someone wants to use the project as an HTTP Service and we have a
bug fix we want them to have as soon as possible.

In that case, we increment the **BUILD** number, and follow the same release
process than for the unified release, except that this gem won't ship with Enterprise Search.

So `8.1.2.1`, `8.1.2.2` etc. On the next unified release, the version will be bumped to
the next **PATCH** value, and **BUILD** set to `0`

**In-Between releases should never introduce new features since they will eventually be
merged into the next PATCH release. New features are always done in Developer previews**

## Developer preview releases

For developer previews, we are adding a `pre` tag using an ISO8601 date.
You can use `make release_dev` instead of `make release` in that case.
