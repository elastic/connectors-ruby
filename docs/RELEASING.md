# Releasing the Connectors project

The Connectors project is packaged as a Gem that is added in the Enterprise Search distribution.

The version scheme we use is **MAJOR.MINOR.PATCH.BUILD** and stored in the `VERSION` file 
at the root of this repository.

**MAJOR.MINOR.PATCH** should match the Elastic and Enterprise Search version it targets 
and the *BUILD* number should be set to **0** the day the release is created
to be included with the Enterprise Search distribution.

For example, when shipping for `8.1.2`, the version is `8.1.2.0`.

To release Connectors:

- set the VERSION file to the right version
- make sure all tests and linter pass with `make lint test`
- run `make release`

A Gem file will be created in the `.gem` directory.
