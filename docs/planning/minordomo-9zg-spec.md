# Implementation Plan: buildAndPushImage — gcloud SDK idempotency fix

**Epic:** minordomo-9zg
**GH Issue:** https://github.com/wcjordan/gcp-setup/issues/36

## Summary

`buildAndPushImage` unconditionally installs the gcloud SDK on every invocation. When called twice in the same dind container, the second call fails because `$HOME/google-cloud-sdk` already exists and the installer refuses to run. The fix guards the install block with an existence check so it is idempotent.

---

## Stage 1: Guard gcloud SDK install with existence check

### Description

In `jenkins-shared-library/vars/buildAndPushImage.groovy`, wrap the `apk add` and `curl` installer lines in an `if [ ! -d "$HOME/google-cloud-sdk" ]` guard so the SDK is only downloaded once per container lifetime. The `export PATH` line must remain outside the guard so subsequent calls still pick up the PATH. Open a PR against the feature branch with this change.

### Acceptance Criteria

- `buildAndPushImage` called twice in the same dind container succeeds on both calls without error.
- `buildAndPushImage` called once in a fresh container still installs the SDK and completes successfully.
- The `export PATH="$HOME/google-cloud-sdk/bin:$PATH"` line is unconditional (not inside the if-guard).
- The changed file passes any existing linters or tests in the repo.
- A PR is opened targeting the feature branch with a clear description referencing GH issue #36.
