# minordomo-6st Research: Add CODEOWNERS file

## Requirement

Add a GitHub CODEOWNERS file so that `wcjordan` is automatically requested as a reviewer on all PRs opened against the `wcjordan/gcp-setup` repository.

## Current State

- No existing CODEOWNERS file found anywhere in the repo.
- No `.github/` directory exists.
- Repo: `wcjordan/gcp-setup`.

## GitHub CODEOWNERS Mechanics

GitHub looks for CODEOWNERS in three locations (in priority order):
1. `.github/CODEOWNERS`
2. Root `CODEOWNERS`
3. `docs/CODEOWNERS`

The `.github/` directory is the canonical location for GitHub-specific configuration.

## Implementation

Create `.github/CODEOWNERS` with the following content:

```
* @wcjordan
```

The `*` glob matches all files, so every PR touching any file will request `wcjordan` as a reviewer.

## Reference

This follows the same pattern used in `wcjordan/minordomo` at commit `46e82c48236661092118beac293a7df070e201ba`.

## Notes

- No tests need to change — CODEOWNERS is a GitHub platform feature, not code.
- No additional configuration required.
- This is a single-file change with no dependencies.
