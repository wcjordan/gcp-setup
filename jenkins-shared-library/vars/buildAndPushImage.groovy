def call(Map config) {
    container(config.get('containerName', 'dind')) {
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
}
