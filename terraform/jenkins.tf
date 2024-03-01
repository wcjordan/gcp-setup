# DNS entry for jenkins
resource "google_compute_global_address" "jenkins_static_ip" {
  name = "${var.project_name}-jenkins-ip"
}

resource "google_dns_record_set" "jenkins-recordset" {
  managed_zone = google_dns_managed_zone.parent-zone.name
  name         = "jenkins.${var.dns_name}."
  type         = "A"
  rrdatas      = [google_compute_global_address.jenkins_static_ip.address]
  ttl          = 1800
}

resource "kubernetes_namespace" "jenkins-worker" {
  metadata {
    name = "jenkins-worker"
    annotations = {
      "cnrm.cloud.google.com/project-id" = var.project_id
    }
  }
}
resource "kubernetes_namespace" "jenkins-namespace" {
  metadata {
    name = "jenkins-controller"
  }
}

# Give default service account access to secrets for Jenkins Kubernetes Credentials Provider plugin
resource "kubernetes_role" "jenkins-secrets-role" {
  metadata {
    name      = "jenkins-secrets"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins-secrets-role-binding" {
  metadata {
    name      = "jenkins-secrets"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "jenkins-secrets"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = "default"
  }
}

# Jenkins k8s plugin GCloud service account
resource "google_service_account" "jenkins" {
  account_id   = "${var.project_name}-jenkins"
  display_name = "${var.project_name} Jenkins service account"
}

resource "google_project_iam_member" "jenkins_compute_role" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_project_iam_member" "jenkins_list_pods_role" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_project_iam_member" "jenkins_storage_buckets_role" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_project_iam_member" "jenkins_sql_addmin_role" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_project_iam_member" "jenkins_artifact_registry_writer_role" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_service_account_key" "jenkins" {
  service_account_id = google_service_account.jenkins.name
}

resource "kubernetes_secret" "jenkins-gke-sa" {
  metadata {
    name = "jenkins-gke-sa"
    labels = {
      "jenkins.io/credentials-type" = "secretFile"
    }
    annotations = {
      "kubernetes.io/credentials-description" = "Credentials for GKE service account"
    }
  }
  data = {
    filename = "gke-sa-key.json"
  }
  binary_data = {
    data = google_service_account_key.jenkins.private_key
  }
}

# Jenkins Helm install
resource "helm_release" "jenkins" {
  name       = "jenkins"
  chart      = "jenkins"
  repository = "https://charts.jenkins.io"
  version    = "5.0.17"

  # Wait for node pool to exist before installing Jenkins to avoid a timeout
  depends_on = [google_container_node_pool.primary_nodes]

## Configure Jenkins Config as Code
## https://github.com/jenkinsci/configuration-as-code-plugin
  values = [
    "${file("charts/jenkins/values.yaml")}",
        <<YAML
controller:
  additionalSecrets:
  - name: browserstack_access_key
    value: "${var.browserstack_access_key}"
  - name: google_service_account_key
    value: "${google_service_account_key.jenkins.private_key}"
  - name: oauth_client_secret
    value: "${var.oauth_client_secret}"
  - name: github_app_private_key
    value: "${var.github_app_private_key}"
  ingress:
    annotations:
      kubernetes.io/ingress.global-static-ip-name: "${var.project_name}-jenkins-ip"
    hostname: "jenkins.${var.dns_name}"
  probes:
    livenessProbe:
      initialDelaySeconds: 600
  resources:
    requests:
      cpu: 500m
      memory: 2048Mi
    limits:
      cpu: 500m
      memory: 2048Mi
  sidecars:
    configAutoReload:
      resources:
        requests:
          cpu: 50m
          memory: 100Mi
        limits:
          cpu: 50m
          memory: 100Mi
  JCasC:
    defaultConfig: false
    configScripts:
      jenkins-casc-configs: |
        credentials:
          system:
            domainCredentials:
            - credentials:
              - googleRobotPrivateKey:
                  id: "gke_key"
                  projectId: "gke_key"
                  serviceAccountConfig:
                    json:
                      secretJsonKey: $${google_service_account_key}
              - browserStack:
                  id: "browserstack_key"
                  username: "${var.browserstack_username}"
                  accesskey: $${browserstack_access_key}
              - gitHubApp:
                  appID: "${var.github_app_id}"
                  description: "GitHub app"
                  id: "github-app"
                  privateKey: $${github_app_private_key}
        jenkins:
          authorizationStrategy:
            globalMatrix:
              entries:
              - user:
                  name: "${var.admin_email}"
                  permissions:
                  - "Overall/Administer"
          clouds:
          - kubernetes:
              containerCap: 4
              containerCapStr: "4"
              credentialsId: "gke_key"
              jenkinsTunnel: "jenkins-agent.default.svc.cluster.local:50000"
              name: "kubernetes"
              namespace: "jenkins-worker"
          globalNodeProperties:
          - envVars:
              env:
              - key: "GCP_PROJECT"
                value: "${var.project_id}"
              - key: "GCP_PROJECT_NAME"
                value: "${var.project_name}"
              - key: "ROOT_DOMAIN"
                value: "${var.dns_name}"
          numExecutors: 0
          primaryView:
            list:
              columns:
              - "status"
              - "weather"
              - "jobName"
              - "lastSuccess"
              - "lastFailure"
              - "lastDuration"
              - "buildButton"
              - "favoriteColumn"
              jobNames:
              - "chalk"
              - "chalk/main"
              - "chalk_base"
              name: "Mainline"
              recurse: true
          securityRealm:
            googleOAuth2:
              clientId: "${var.oauth_client_id}"
              clientSecret: $${oauth_client_secret}
          views:
          - list:
              columns:
              - "status"
              - "weather"
              - "jobName"
              - "lastSuccess"
              - "lastFailure"
              - "lastDuration"
              - "buildButton"
              - "favoriteColumn"
              jobNames:
              - "chalk"
              - "chalk/main"
              - "chalk_base"
              name: "Mainline"
              recurse: true
          - all:
              name: "all"
        security:
          queueItemAuthenticator:
            authenticators:
            - global:
                strategy:
                  specificUsersAuthorizationStrategy:
                    userid: "${var.admin_email}"
        unclassified:
          defaultFolderConfiguration:
            healthMetrics:
            - "primaryBranchHealthMetric"
          location:
            adminAddress: "${var.admin_email}"
            url: "http://jenkins.${var.dns_name}/"
          timestamper:
            allPipelines: true
YAML
  ]
}
