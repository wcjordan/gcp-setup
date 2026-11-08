# gcp-setup

Terraform for a GKE cluster plus Jenkins (Helm), cert-manager and supporting GCP resources.
Terraform runs in **Terraform Cloud** (VCS workflow on the `terraform/` directory): pushing to
`main` triggers a plan there. There is no local backend, so local `terraform plan` isn't the
source of truth — the user evaluates the TFC plan after a push.

## Bumping dependencies

### Where versions are pinned

| Dependency | File | Where to find the latest |
|---|---|---|
| Jenkins Helm chart | `terraform/jenkins.tf` (`helm_release.jenkins` `version`) | `https://charts.jenkins.io/index.yaml` (`entries.jenkins[0].version`) |
| Terraform providers (google, helm, kubectl, kubernetes) | `terraform/init.tf` (`required_providers`) | `https://registry.terraform.io/v1/providers/<namespace>/<name>` (`.version`) |
| cert-manager chart | `terraform/gke_cluster.tf` (`helm_release.cert-manager` `version`) | `https://charts.jetstack.io/index.yaml`, or GitHub releases for `cert-manager/cert-manager` |
| Helm CLI in the Jenkins helm image | `jenkins/Dockerfile.helm` (both the tarball and `.sha256` URLs) | GitHub releases for `helm/helm` |
| Docker-in-Docker build image | `jenkins/Jenkinsfile.helm-image` (`docker:<major>-dind`) | Docker Hub `library/docker` tags |
| Cloud SQL Postgres | `terraform/gcp_other.tf` (`database_version`) | Match what's actually running; don't bump casually |

`required_version` in `init.tf` is a minimum, not a pin — leave it unless a provider needs newer Terraform.
`google-cloud-cli:alpine` in `Dockerfile.helm` is intentionally unpinned.

Past bump commits are small and focused (e.g. `git log --grep=Bump`); follow that style.

### Before bumping, read the changelog

- **Jenkins chart**: `charts/jenkins/CHANGELOG.md` in `jenkinsci/helm-charts`. Check for image/JDK
  changes and security-context changes against `terraform/charts/jenkins/values.yaml`
  (plugins in `installPlugins` are unpinned on purpose).
- **Providers**: for major versions, read the provider's upgrade guide and grep the repo for every
  resource/field it mentions (`grep -hoE '^(resource|data) "<prefix>_[a-z0-9_]+"' terraform/*.tf | sort -u`).
- **cert-manager**: upgrade **one minor version at a time** (latest patch of each minor), one
  commit + apply per step. Read each minor's release notes in `cert-manager/website`
  (`content/docs/releases/release-notes/release-notes-<minor>.md`).

### Validate locally

`terraform validate` catches syntax/schema breaks but not provider-config validation that
depends on computed values. Validate against a scratch copy so `.terraform/` doesn't land in the repo:

```
cp -R terraform/*.tf terraform/charts <scratch>/ && cd <scratch> && terraform init -backend=false && terraform validate
```

For provider-config checks that need values (like `host`), a tiny scratch config with a
`var.host` and one data source, run through `terraform plan`, reproduces the error without the cluster.

### Workflow

1. Bump, validate, commit (one logical change per commit; risky bumps get their own commit).
2. Ask before pushing — pushing to `main` triggers the TFC plan the user reviews.
3. If the TFC plan fails, revert just the offending bump, push, then investigate separately.

## Known gotchas

- **Kubernetes-facing provider `host`** (`kubectl`, `kubernetes`, `helm` in `init.tf`) must be
  `"https://${google_container_cluster.primary.endpoint}"`. The bare endpoint is an IP, and
  kubernetes provider ≥ 3.5 rejects it with `'host' is not a valid URL`.
- **Helm provider 3.x** uses nested-object syntax: `kubernetes = { ... }` in the provider and
  `set = [ { ... } ]` on `helm_release` (not blocks).
- **cert-manager is live**: `prod/chalk-prod` (GCE Ingress, `acme.cert-manager.io/http01-edit-in-place: "true"`)
  gets its Let's Encrypt cert via HTTP-01 from `letsencrypt-cluster-cert-issuer`. After a
  cert-manager upgrade, verify with `kubectl get deploy -n cert-manager -o wide` and
  `kubectl get certificate,certificaterequest -n prod`. To exercise a real challenge, run
  `cmctl renew tls-cert -n prod` — but Let's Encrypt reuses a valid authorization for ~30 days
  after the last challenge, so a renewal within that window won't create a Challenge and proves nothing.
- Since cert-manager v1.18, HTTP-01 Ingress paths use `pathType: Exact`. If challenges fail on
  GKE Ingress, set the feature gate `ACMEHTTP01IngressPathTypeExact=false` on the cert-manager release.
- `kubectl get -w` only accepts a single resource type; use `watch -n5 kubectl get a,b,c` instead.
