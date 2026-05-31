# Research: minordomo-low — Jenkins Helm Image & Shared Library

## Repo Structure (gcp-setup)
- `terraform/` — all Terraform configuration
  - `jenkins.tf` — Jenkins DNS, RBAC, service accounts, and Helm release
  - `charts/jenkins/values.yaml` — Jenkins Helm chart values (plugins, ingress)
  - `gcp_other.tf` — GAR repository, Cloud SQL, DNS zone, storage
  - `variables.tf` — Terraform input variables
  - `init.tf` — Provider config (google, helm, kubernetes, kubectl)

## No `jenkins/` Directory Yet
The repo currently has no `jenkins/` subdirectory. One must be created for:
- `jenkins/Dockerfile.helm`
- `jenkins/Jenkinsfile.helm-image`

## No `jenkins-shared-library/` Directory Yet
Must be created at:
- `jenkins-shared-library/vars/buildAndPushImage.groovy`

## Jenkins Helm Release (terraform/jenkins.tf)
- Chart version: `5.9.18`
- JCasC configured via `configScripts.jenkins-casc-configs` inline YAML
- Current JCasC covers: credentials, clouds (k8s), globalNodeProperties, views, security, unclassified
- **No job definitions in JCasC** — jobs appear to be created manually or via GitHub discovery
- Installed plugins (values.yaml): no `job-dsl` plugin currently listed

## Plugin Gaps for This Feature
To register a pipeline job declaratively in JCasC, the `job-dsl` plugin is needed.
It must be added to `controller.installPlugins` in `charts/jenkins/values.yaml`.

## GAR Configuration
- GAR repository managed in `gcp_other.tf` as `google_artifact_registry_repository.primary`
- Repository ID: `${var.project_name}-gar`
- Location: `${var.gcp_region}`
- Format: DOCKER
- Cleanup: delete after 90 days, keep last 5 versions

## Existing Jenkins GCR/GAR Auth
- Plugin `google-container-registry-auth` is installed
- Credential `jenkins-gke-sa` (secretFile, GKE service account JSON) already exists in k8s and JCasC

## JCasC Global Env Vars
Available to all Jenkins jobs:
- `GCP_PROJECT` = `${var.project_id}`
- `GCP_PROJECT_NAME` = `${var.project_name}`
- `ROOT_DOMAIN` = `${var.dns_name}`
- `JIRA_CLOUD_ID` = `${var.jira_cloud_id}`

The `GAR_REPO` var (used in the Jenkinsfile as `${GAR_REPO}/jenkins-helm:latest`) is not currently set.
This needs to be added as a global env var in JCasC, or hardcoded in the Jenkinsfile using GCP_PROJECT vars.

## Shared Library Registration Format (from Issue)
```yaml
globalLibraries:
  libraries:
    - name: "jenkins-shared-library"
      retriever:
        modernSCM:
          scm:
            git:
              remote: "https://github.com/wcjordan/gcp-setup.git"
              includes: "*"
          libraryPath: "jenkins-shared-library/"
```
This goes in the `unclassified:` section of JCasC.

## Dockerfile.helm Source
Comes from minordomo repo (gcloud-cli alpine + kubectl + helm). The exact content is not available in this repo but is described as: gcloud-cli alpine base + kubectl + helm, same versions as currently used in minordomo and chalk.
The worker will need to reference the minordomo Dockerfile.helm for pinned versions.

## Key Open Question: GAR_REPO env var
The issue's Jenkinsfile uses `${GAR_REPO}` as a variable. This env var is not currently defined in JCasC global env vars. Options:
1. Add `GAR_REPO` global env var to JCasC (e.g., `${gcp_region}-docker.pkg.dev/${project_id}/${project_name}-gar`)
2. Construct it inline in the Jenkinsfile from existing `GCP_PROJECT` and `GCP_PROJECT_NAME` env vars
