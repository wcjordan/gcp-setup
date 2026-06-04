# Research: buildAndPushImage gcloud SDK Idempotency Fix

## File Under Study

`jenkins-shared-library/vars/buildAndPushImage.groovy`

## Problem

Lines 13-15 unconditionally install the gcloud SDK on every invocation:

```sh
apk add --no-cache bash curl python3
curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
```

When `buildAndPushImage` is called twice in the same dind container (same Jenkins stage), the second call fails because `$HOME/google-cloud-sdk` already exists and the installer refuses to overwrite it.

## Fix

Guard the `apk` + SDK install with an existence check so it's idempotent:

```sh
if [ ! -d "$HOME/google-cloud-sdk" ]; then
    apk add --no-cache bash curl python3
    curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts
fi
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
```

The `export PATH` line must always run (not guarded) so subsequent calls pick up the PATH even if the SDK was already installed.

## Scope

Single-file change. No other Groovy vars, no Jenkinsfiles, no tests in this repo reference `buildAndPushImage` installation logic. The fix is self-contained.

## Reproducer

chalk PR #311 — "Build UI" stage calls `buildAndPushImage` twice (targets `js_app_prod` and `js_test_env`) in the same dind container.
