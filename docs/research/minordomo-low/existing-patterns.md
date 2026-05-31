# Existing Patterns: dind Build & Jenkins Helm Image

## Minordomo's Existing Dockerfile.helm
Path: `minordomo-container-builder/Dockerfile.helm`
```dockerfile
FROM us.gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine

RUN gcloud components install kubectl -q --no-user-output-enabled

RUN mkdir helm_tmp \
  && curl -fsSL -o helm_tmp/helm.tar.gz https://get.helm.sh/helm-v4.1.4-linux-amd64.tar.gz \
  && curl -fsSL -o helm_tmp/helm.tar.gz.sha256 https://get.helm.sh/helm-v4.1.4-linux-amd64.tar.gz.sha256 \
  && cd helm_tmp \
  && echo "$(head -n 1 helm.tar.gz.sha256) helm.tar.gz" > helm.tar.gz.sha256 \
  && sha256sum -c helm.tar.gz.sha256 \
  && tar -zxvf helm.tar.gz -C . \
  && mv linux-amd64/helm /bin/helm \
  && cd .. \
  && rm -rf helm_tmp
```

## Minordomo's Existing Jenkinsfile (Build Helm Image Stage)
Key patterns from `minordomo-container-builder/Jenkinsfile`:
- GAR_HOST: `'us-east4-docker.pkg.dev'` (hardcoded)
- GAR_REPO: `"${GAR_HOST}/${env.GCP_PROJECT}/default-gar"` (uses env var)
- dind pod: inline YAML, `docker:27-dind`, privileged, 500m/1Gi-2Gi resources
- cron trigger: `cron('H 2 * * 0')` (Sundays ~2 AM)
- Credentials: `jenkins-gke-sa` secretFile
- Uses `docker buildx` with registry cache

Full dind bootstrap (copy/paste pattern to encapsulate in shared library):
```sh
set -euo pipefail
apk add --no-cache bash curl python3
curl -fsSL https://sdk.cloud.google.com | bash -s -- --disable-prompts
export PATH="$HOME/google-cloud-sdk/bin:$PATH"
gcloud auth activate-service-account --key-file "$GKE_SA_FILE"
gcloud auth configure-docker ${GAR_HOST} --quiet
while ! docker stats --no-stream 2>/dev/null; do
    echo "Waiting for Docker to launch..."
    sleep 1
done
docker buildx create --driver docker-container --name helm-builder --use || true
docker buildx build --push \
    --cache-to  type=registry,ref=${GAR_REPO}/jenkins-helm-cache:latest,mode=max \
    --cache-from type=registry,ref=${GAR_REPO}/jenkins-helm-cache:latest \
    -f minordomo-container-builder/Dockerfile.helm \
    -t ${GAR_REPO}/jenkins-helm:latest \
    .
```

## Chalk's Jenkins Patterns
- chalk uses `default-gar` for its GAR repo name (different from gcp-setup's `${project_name}-gar`)
- chalk has a separate `jenkins/dockerHelper.groovy` for auth; minordomo inlines everything
- chalk uses `jenkins-worker-dind.yml` file; minordomo uses inline pod YAML in Jenkinsfile

## GAR Naming
- gcp-setup GAR repo is named `${var.project_name}-gar` (from gcp_other.tf)
- minordomo Jenkinsfile uses `default-gar` — this appears to be an existing GAR repo in the shared GCP project
- New jenkins-helm builds should push to the same GAR repo as minordomo currently uses
- Worker should confirm the correct GAR repo name by checking what `${env.GCP_PROJECT}/default-gar` resolves to

## Job DSL Plugin Required
The `job-dsl` plugin is NOT currently in `charts/jenkins/values.yaml`.
To register the pipeline job declaratively via JCasC, the worker must add `job-dsl` to `controller.installPlugins` in values.yaml.

## JCasC Location for Global Libraries
Should go under `unclassified:` section in the JCasC configScript in jenkins.tf.

## JCasC Location for New Job
Should go as a new `jobs:` section in the JCasC configScript, using Job DSL groovy syntax.
The new job should also be added to the `jobNames` list in the primary view.
