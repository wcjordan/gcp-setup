# Implementation Plan: Extend buildAndPushImage

**Epic:** minordomo-c5x
**GH Issue:** https://github.com/wcjordan/gcp-setup/issues/22

## Summary

Extend `jenkins-shared-library/vars/buildAndPushImage.groovy` to accept four new optional parameters — `context`, `target`, `extraBuildArgs`, and `additionalCacheFrom` — enabling chalk's CI pipeline to use this step for multi-stage, multi-cache-ref Docker builds. All existing callers remain backward-compatible via defaults.

---

## Stage 1: Extend buildAndPushImage with context, target, extraBuildArgs, and additionalCacheFrom

### Description

Modify `jenkins-shared-library/vars/buildAndPushImage.groovy` to accept four new optional parameters with appropriate defaults, keeping the existing `Jenkinsfile.helm-image` caller working without any changes.

**Changes:**

1. Add `context` (String, default `'.'`) — replaces the hardcoded `.` at the end of the `docker buildx build` command.

2. Add `target` (String, default `''`) — adds `--target <stage>` to the build command only when non-empty.

3. Add `extraBuildArgs` (String, default `''`) — appended verbatim to the `docker buildx build` invocation, after all other flags and before the build context. The caller is responsible for proper quoting/escaping.

4. Add `additionalCacheFrom` (List<String>, default `[]`) — each element becomes an additional `--cache-from type=registry,ref=<element>` flag. The existing `cacheRef` still generates both `--cache-to` and `--cache-from`; `additionalCacheFrom` adds more `--cache-from` only.

**Implementation approach:** Compute flag strings as Groovy local variables before the `sh """..."""` block, then interpolate into the shell string. This avoids complex logic inside the heredoc:

```groovy
def context = config.get('context', '.')
def targetFlag = config.get('target', '') ? "--target ${config.get('target')}" : ''
def extraBuildArgs = config.get('extraBuildArgs', '')
def additionalCacheFromFlags = config.get('additionalCacheFrom', [])
    .collect { "--cache-from type=registry,ref=${it}" }
    .join(' ')
```

Then the `docker buildx build` command becomes:
```
docker buildx build --push \
    --cache-to  type=registry,ref=${cacheRef},mode=max \
    --cache-from type=registry,ref=${cacheRef} \
    ${additionalCacheFromFlags} \
    -f ${dockerfile} \
    -t ${imageTag} \
    ${targetFlag} \
    ${extraBuildArgs} \
    ${context}
```

Note: Groovy variables computed before the `sh` block are interpolated via `${}` in the triple-quoted string. Jenkins-environment variables (like `$HOME`, `$PATH`) inside the shell script use `\$` to prevent Groovy from intercepting them.

### Acceptance Criteria

- `buildAndPushImage` accepts all four new parameters: `context`, `target`, `extraBuildArgs`, `additionalCacheFrom`
- All four parameters have working defaults that preserve the current behavior
- The existing `jenkins/Jenkinsfile.helm-image` caller works without modification
- When `context: 'ui'` is passed, the build context `ui` is used instead of `.`
- When `target: 'js_app_prod'` is passed, `--target js_app_prod` appears in the docker command
- When `extraBuildArgs: '--build-arg sentryDsn=abc'` is passed, it appears in the docker command
- When `additionalCacheFrom: ['some/cache:tag']` is passed, `--cache-from type=registry,ref=some/cache:tag` is added alongside the primary `--cache-from`
- When `target` is empty string or omitted, no `--target` flag appears in the command
- When `additionalCacheFrom` is empty list or omitted, no additional `--cache-from` flags appear
