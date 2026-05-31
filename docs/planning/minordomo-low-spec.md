# Implementation Plan: Add Shared jenkins-helm Image, Weekly Build Job, and dind Shared Library

**GH Issue:** https://github.com/wcjordan/gcp-setup/issues/16

## Overview

This plan moves the `jenkins-helm` Docker image build to `gcp-setup`, adds a weekly build job, and creates a Jenkins shared library encapsulating the dind bootstrap pattern. Three stages cover the four subtasks from the issue (1a, 1c, and 1b+1d grouped by concern).

---

## Stage 1: Add Dockerfile.helm to gcp-setup/jenkins/

### Description

Copy the `Dockerfile.helm` from minordomo into `gcp-setup/jenkins/Dockerfile.helm`. This establishes `gcp-setup` as the canonical home for the jenkins-helm image. No other files change in this stage.

The exact file to copy is `minordomo-container-builder/Dockerfile.helm` from the minordomo repo (current content: gcloud-cli alpine base + kubectl + helm v4.1.4). The worker should verify the pinned versions in minordomo's Dockerfile.helm match those in chalk's `jenkins/gcloud_helm.Dockerfile` (if chalk has one) and use whichever is most recent.

### Acceptance Criteria
- `gcp-setup/jenkins/Dockerfile.helm` exists with the correct content (gcloud-cli alpine base, kubectl, helm with a pinned version and SHA256 verification)
- File content matches what is currently in `minordomo-container-builder/Dockerfile.helm` (or a newer pin if one exists)
- No other files are modified

---

## Stage 2: Create the Jenkins Shared Library

### Description

Create the Jenkins shared library directory structure and the `buildAndPushImage` step. This encapsulates the dind bootstrap pattern (install gcloud SDK, authenticate to GAR, wait for Docker, run buildx).

**Create `gcp-setup/jenkins-shared-library/vars/buildAndPushImage.groovy`** with the following content (from the issue):

```groovy
def call(Map config) {
    withCredentials([file(credentialsId: config.get('credentialsId', 'jenkins-gke-sa'), variable: 'GKE_SA_FILE')]) {
        sh """
            set -euo pipefail
            apk add --no-cache bash curl python3
            curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts
            export PATH="\$HOME/google-cloud-sdk/bin:\$PATH"
            gcloud auth activate-service-account --key-file "\$GKE_SA_FILE"
            gcloud auth configure-docker ${config.garHost} --quiet
            while ! docker stats --no-stream 2>/dev/null; do
                echo "Waiting for Docker to launch..."
                sleep 1
            done
            docker buildx create --driver docker-container --name ${config.get('builderName', 'default-builder')} --use || true
            docker buildx build --push \\
                --cache-to  type=registry,ref=${config.cacheRef},mode=max \\
                --cache-from type=registry,ref=${config.cacheRef} \\
                -f ${config.dockerfile} \\
                -t ${config.imageTag} \\
                .
        """
    }
}
```

### Acceptance Criteria
- `gcp-setup/jenkins-shared-library/vars/buildAndPushImage.groovy` exists with the above content
- No other files are modified in this stage

---

## Stage 3: Add Weekly Jenkinsfile and Wire Up JCasC

### Description

This stage creates the weekly build pipeline and registers both the shared library and the new job in Jenkins JCasC via Terraform. Three changes are made:

**A. Create `gcp-setup/jenkins/Jenkinsfile.helm-image`**

Model after `minordomo-container-builder/Jenkinsfile`'s "Build and Push Helm Image" stage. Use:
- `triggers { cron('H 3 * * 0') }` (Sundays, offset from minordomo's `H 2 * * 0`)
- `GAR_HOST = 'us-east4-docker.pkg.dev'`
- `GAR_REPO = "${GAR_HOST}/${env.GCP_PROJECT}/default-gar"` (same pattern as minordomo)
- Inline dind pod YAML (docker:27-dind, privileged, 500m CPU / 1Gi-2Gi memory)
- Single stage that calls `buildAndPushImage` from the shared library:
  ```groovy
  @Library('jenkins-shared-library') _

  def GAR_HOST = 'us-east4-docker.pkg.dev'
  def GAR_REPO = "${GAR_HOST}/${env.GCP_PROJECT}/default-gar"

  pipeline {
      agent none
      options { timestamps() }
      triggers { cron('H 3 * * 0') }
      stages {
          stage('Build and Push Helm Image') {
              agent {
                  kubernetes {
                      yaml """
                          apiVersion: v1
                          kind: Pod
                          spec:
                            containers:
                            - name: dind
                              image: docker:27-dind
                              securityContext:
                                privileged: true
                              resources:
                                requests:
                                  cpu: "500m"
                                  memory: "1Gi"
                                limits:
                                  cpu: "1000m"
                                  memory: "2Gi"
                      """
                  }
              }
              options { timeout(time: 15, unit: 'MINUTES') }
              steps {
                  container('dind') {
                      buildAndPushImage(
                          garHost: GAR_HOST,
                          cacheRef: "${GAR_REPO}/jenkins-helm-cache:latest",
                          dockerfile: 'jenkins/Dockerfile.helm',
                          imageTag: "${GAR_REPO}/jenkins-helm:latest",
                          builderName: 'helm-builder'
                      )
                  }
              }
          }
      }
  }
  ```

**B. Add `job-dsl` plugin to `terraform/charts/jenkins/values.yaml`**

Add `job-dsl` to the `controller.installPlugins` list (alphabetical order, after `google-login`).

**C. Update `terraform/jenkins.tf` JCasC configuration**

Two additions to the existing JCasC `configScripts.jenkins-casc-configs` block:

1. **Register the shared library** — add a `globalLibraries:` block under the existing `unclassified:` section:
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

2. **Register the pipeline job** — add a `jobs:` section to the JCasC script:
   ```yaml
   jobs:
     - script: >
         pipelineJob('jenkins-helm-image') {
           definition {
             cpsScm {
               scm {
                 git {
                   remote {
                     url('https://github.com/wcjordan/gcp-setup.git')
                     credentials('github-app')
                   }
                   branches('*/main')
                 }
               }
               scriptPath('jenkins/Jenkinsfile.helm-image')
             }
           }
         }
   ```

3. **Add job to the primary view** — add `jenkins-helm-image` to the `jobNames` list in both the `primaryView` and the `views` list view in the JCasC.

### Acceptance Criteria
- `gcp-setup/jenkins/Jenkinsfile.helm-image` exists with a cron trigger, dind pod spec, and calls `buildAndPushImage` from the shared library
- `job-dsl` plugin is added to `terraform/charts/jenkins/values.yaml`
- `terraform/jenkins.tf` JCasC includes a `globalLibraries` entry for `jenkins-shared-library` pointing to `gcp-setup`
- `terraform/jenkins.tf` JCasC includes a `jobs` entry that creates the `jenkins-helm-image` pipeline job
- `jenkins-helm-image` is added to the primary view's job list in JCasC
- All Terraform files are valid (`terraform validate` or equivalent syntax check passes if available)
