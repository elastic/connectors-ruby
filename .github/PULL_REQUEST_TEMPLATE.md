## Closes https://github.com/elastic/connectors/issues/###


<!--Provide a general description of the code changes in your pull request.
If the change relates to a specific issue, include the link at the top.

If this is an ad-hoc/trivial change and does not have a corresponding
issue, please describe your changes in enough details, so that reviewers
and other team members can understand the reasoning behind the pull request.-->

## Checklists

<!--You can remove unrelated items from checklists below and/or add new
items that may help during the review.-->

#### Pre-Review Checklist
- [ ] Covered the changes with automated tests
- [ ] Tested the changes locally
- [ ] Added a label for each target release version (example: `v7.13.2`, `v7.14.0`, `v8.0.0`)

#### Changes Requiring Extra Attention

<!--Please call out any changes that require special attention from the
reviewers and/or increase the risk to availability or security of the
system after deployment. Remove the ones that don't apply.-->

- [ ] Security-related changes (encryption, TLS, SSRF, etc)
- [ ] New external service dependencies added.

## Related Pull Requests

<!--List any relevant PRs here or remove the section if this is a standalone PR.

* https://github.com/elastic/.../pull/123-->

## Release Note

<!--If you think this enhancement/fix should be included in the release notes,
please write a concise user-facing description of the change here.
You should also label the PR with `release_note` so the release notes
author(s) can easily look it up.-->

## For Elastic Internal Use Only
- [ ] Considered corresponding documentation changes to [contribute separately](https://github.com/elastic/enterprise-search-pubs#contribute-docs-changes-for-product-changes)
- [ ] New configuration settings added in this PR follow the [official guidelines](https://github.com/elastic/ent-search/blob/main/doc/enterprise-search-config.md)
- [ ] [Manual test steps](https://github.com/elastic/connectors/blob/main/docs/INTERNAL.md#minimal-manual-tests)  are successful
- [ ] Enterprise Search builds successfully with a gem built from this PR's branch.
  - _Link the ent-search PR here_
