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

resource "google_service_account_key" "jenkins" {
  service_account_id = google_service_account.jenkins.name
}

# Create ConfigMap for Jenkins Config as Code (CasC) configuration
# Also creates secrets for CasC ConfigMap to use
resource "kubernetes_secret" "jenkins" {
  metadata {
    name = "jenkins-secrets"
  }

  data = {
    browserstack_access_key    = var.browserstack_access_key
    google_service_account_key = google_service_account_key.jenkins.private_key
    oauth_client_secret        = var.oauth_client_secret
  }
}

locals {
  casc_config = templatefile("jenkins-casc-config.yaml.tpl", {
    project_id            = var.project_id,
    admin_email           = var.admin_email,
    dns_name              = var.dns_name,
    browserstack_username = var.browserstack_username,
    oauth_client_id       = var.oauth_client_id,
  })
}
resource "kubernetes_config_map" "jenkins-casc-config" {
  metadata {
    name = "jenkins-casc-config"
  }

  data = {
    "jenkins-casc-config.yaml" : "${local.casc_config}"
  }
}

# Jenkins Helm install
resource "helm_release" "jenkins" {
  name  = "jenkins-ci"
  chart = "bitnami/jenkins"

  # Wait for node pool to exist before installing Jenkins to avoid a timeout
  depends_on = [google_container_node_pool.primary_nodes]


  values = [
    "${file("../charts/jenkins/values.yaml")}"
  ]
  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.global-static-ip-name"
    value = "${var.project_name}-jenkins-ip"
  }
  set {
    name  = "ingress.extraHosts[0].name"
    value = "jenkins.${var.dns_name}"
  }
  set {
    name  = "ingress.extraHosts[0].path"
    value = "/*"
  }
}
