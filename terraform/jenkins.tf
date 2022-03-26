# DNS zone & entry for jenkins
resource "google_dns_managed_zone" "parent-zone" {
  name        = "${var.project_name}-dns"
  dns_name    = "${var.dns_name}."
  description = "Top level DNS zone for ${var.project_name}."
}

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

# Give default service account access to secrets for Jenkins Kubernetes Credentials Provider plugin
resource "kubernetes_role" "jenkins-secrets" {
  metadata {
    name      = "jenkins-secrets"
    namespace = "default"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    # resource_names = ["jenkins-gke-sa"]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins-secrets" {
  metadata {
    name      = "jenkins-secrets"
    namespace = "default"
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

resource "kubernetes_secret" "chalk-oauth-web-secret" {
  metadata {
    name = "chalk-oauth-web-secret"
    labels = {
      "jenkins.io/credentials-type" = "secretFile"
    }
    annotations = {
      "kubernetes.io/credentials-description" = "OAuth secret for web logins used by Chalk build"
    }
  }
  data = {
    filename = "oauth_web_client_secret.json"
  }
  binary_data = {
    data = base64encode(var.chalk_oauth_client_secret)
  }
}

resource "kubernetes_secret" "github-ssh-key-secret" {
  metadata {
    name = "github-ssh-key-secret"
    labels = {
      "jenkins.io/credentials-type" = "basicSSHUserPrivateKey"
    }
    annotations = {
      "kubernetes.io/credentials-description" = "SSH private key for Jenkins to access Github repos"
    }
  }
  data = {
    username = "github_ssh"
  }
  binary_data = {
    privateKey = base64encode(var.github_ssh_key)
  }
}

resource "kubernetes_namespace" "jenkins-worker" {
  metadata {
    name = "jenkins-worker"
  }
}

# Jenkins Helm install
resource "helm_release" "jenkins" {
  name       = "jenkins"
  chart      = "jenkins"
  repository = "https://charts.jenkins.io"

  # Wait for node pool to exist before installing Jenkins to avoid a timeout
  depends_on = [google_container_node_pool.primary_nodes]

## Configure Jenkins Config as Code
## https://github.com/jenkinsci/configuration-as-code-plugin
  values = [
    "${file("charts/jenkins/values.yaml")}",
        <<EOT
controller:
  additionalSecrets:
  - name: browserstack_access_key
    value: "${var.browserstack_access_key}"
  - name: google_service_account_key
    value: "${google_service_account_key.jenkins.private_key}"
  - name: oauth_client_secret
    value: "${var.oauth_client_secret}"
  ingress:
    annotations:
      kubernetes.io/ingress.global-static-ip-name: "${var.project_name}-jenkins-ip"
    hostname: "jenkins.${var.dns_name}"
  jenkinsAdminEmail: "${var.admin_email}"
  jenkinsUrl: "http://jenkins.${var.dns_name}/"
  JCasC:
    defaultConfig: false
    authorizationStrategy: |-
      globalMatrix:
        permissions:
        - "USER:Overall/Administer:${var.admin_email}"
    securityRealm: |-
      googleOAuth2:
        clientId: "${var.oauth_client_id}"
        clientSecret: $${oauth_client_secret}
    configScripts:
      jenkins-casc-configs: |
        credentials:
          system:
            domainCredentials:
            - credentials:
              - googleRobotPrivateKey:
                  projectId: "gke_key"
                  serviceAccountConfig:
                    json:
                      secretJsonKey: $${google_service_account_key}
              - browserStack:
                  id: "browserstack_key"
                  username: "${var.browserstack_username}"
                  accesskey: $${browserstack_access_key}
        jenkins:
          clouds:
          - kubernetes:
              containerCap: 4
              containerCapStr: "4"
              credentialsId: "gke_key"
              jenkinsTunnel: "jenkins-agent.default.svc.cluster.local:50000"
              name: "kubernetes"
          globalNodeProperties:
          - envVars:
              env:
              - key: "GCP_PROJECT"
                value: "${var.project_id}"
              - key: "GCP_PROJECT_NAME"
                value: "${var.project_name}"
              - key: "OAUTH_REFRESH_TOKEN"
                value: "${var.oauth_refresh_token}"
              - key: "SENTRY_DSN"
                value: "${var.sentry_dsn}"
              - key: "SENTRY_TOKEN"
                value: "${var.sentry_token}"
          numExecutors: 0
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
          timestamper:
            allPipelines: true
EOT
  ]
}
