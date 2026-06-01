# Research: buildAndPushImage Extension

## Current Implementation

`jenkins-shared-library/vars/buildAndPushImage.groovy` is a single-function Jenkins shared library step (~25 lines). It:

1. Wraps execution in a named container (default: `dind`)
2. Loads a GCP service account key credential
3. Installs gcloud SDK inside the container
4. Authenticates to GAR
5. Waits for Docker daemon
6. Creates a buildx builder
7. Runs `docker buildx build --push` with hardcoded:
   - Build context: `.`
   - Single `--cache-from` matching `cacheRef`
   - No `--target`
   - No extra build args

## Current Parameters (config Map)

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `containerName` | No | `'dind'` | Container name to exec inside |
| `credentialsId` | No | `'jenkins-gke-sa'` | Jenkins credential ID for GCP SA key |
| `garHost` | Yes | — | GAR hostname for `gcloud auth configure-docker` |
| `cacheRef` | Yes | — | Registry ref used for both `--cache-to` and `--cache-from` |
| `dockerfile` | Yes | — | Path to Dockerfile |
| `imageTag` | Yes | — | Full image tag to push |
| `builderName` | No | `'default-builder'` | buildx builder name |

## Existing Callers

Only one caller: `jenkins/Jenkinsfile.helm-image`. It passes:
- `garHost`, `cacheRef`, `dockerfile`, `imageTag`, `builderName`
- Does NOT pass: context, target, extraBuildArgs, additionalCacheFrom (all new defaults must be backward-compatible)

## Test Infrastructure

**None exists.** No Maven/Gradle build, no JenkinsPipelineUnit, no Groovy test scripts. The repo is infrastructure-focused (Terraform + Jenkins config).

## Required Changes (from GH Issue #22)

Four new parameters needed:

| Parameter | Type | Default | Usage |
|-----------|------|---------|-------|
| `context` | String | `'.'` | Build context path passed to `docker buildx build` |
| `target` | String | `''` | `--target <stage>` flag (omitted when empty) |
| `extraBuildArgs` | String | `''` | Appended verbatim to the `docker buildx build` command |
| `additionalCacheFrom` | List<String> | `[]` | Each entry becomes an additional `--cache-from type=registry,ref=<entry>` |

## Implementation Notes

- `context` replaces the hardcoded `.` at end of the docker build command
- `target` should only appear in the command when non-empty (Groovy `?` null-safe or explicit check)
- `extraBuildArgs` is a raw string appended to the shell command — the caller is responsible for proper quoting
- `additionalCacheFrom` entries join with `--cache-from type=registry,ref=` prefix for each item
- `cacheRef` still generates both `--cache-to` and `--cache-from`; `additionalCacheFrom` is additional `--cache-from` only

## Groovy Multiline Shell String Pattern

Current code uses `sh """..."""`. New parameters should be interpolated inside the triple-quoted string using `${}` Groovy interpolation or built up as a local variable before the `sh` call.

For `additionalCacheFrom` (a list), build the flags as a Groovy string:
```groovy
def additionalCacheFromFlags = config.get('additionalCacheFrom', [])
    .collect { "--cache-from type=registry,ref=${it}" }
    .join(' ')
```

For `target`:
```groovy
def targetFlag = config.target ? "--target ${config.target}" : ''
```
