variable "project_id" {
  default     = ""
  description = "project ID to use"
}
variable "project_name" {
  default     = ""
  description = "project name to use"
}

terraform {
  required_providers {
    google = {
      # Using beta for config_connector_config
      source  = "hashicorp/google-beta"
      version = "3.74.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.2.0"
    }
  }

  required_version = ">= 1.0.1"
}

provider "google" {
  credentials = file("service_account_key.json")

  project = var.project_id
  region  = "us-east4"
  zone    = "us-east4-c"
}

data "google_client_config" "current" {}


# GKE service account
resource "google_service_account" "gke" {
  account_id   = "${var.project_name}-gke"
  display_name = "${var.project_name} GKE node service account"
}

resource "google_project_iam_member" "gke_gcr" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name = "${var.project_name}-gke"

  enable_shielded_nodes = true
  release_channel {
    channel = "RAPID"
  }
  workload_identity_config {
    identity_namespace = "${var.project_id}.svc.id.goog"
  }
  addons_config {
    config_connector_config {
      enabled = true
    }
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

# Separately Managed Node Pool which allows Terraform to manage it
resource "google_container_node_pool" "primary_nodes" {
  name    = "${var.project_name}-gke-node-pool"
  cluster = google_container_cluster.primary.name

  initial_node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    preemptible  = true
    machine_type = "e2-standard-4"
    tags         = ["gke-node", "${var.project_name}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    labels = {
      env = var.project_name
    }
    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
    shielded_instance_config {
      enable_secure_boot = true
    }

    # Works around an issue where Terraform tries to update the node pool when nothing's changed
    kubelet_config {
      cpu_manager_policy = "none"
      cpu_cfs_quota      = null
    }

    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}



# CNRM Config Connector service account
resource "google_service_account" "cnrm" {
  account_id   = "${var.project_name}-cnrm"
  display_name = "${var.project_name} CNRM Config Connector service account"
}

resource "google_project_iam_member" "cnrm_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.cnrm.email}"
}

resource "google_project_iam_member" "cnrm_iam_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.cnrm.email}"
}

resource "google_project_iam_member" "cnrm_project_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.cnrm.email}"
}

data "google_iam_policy" "cnrm" {
  binding {
    role = "roles/iam.workloadIdentityUser"
    members = [
      "serviceAccount:${var.project_id}.svc.id.goog[cnrm-system/cnrm-controller-manager]",
    ]
  }
}

resource "google_service_account_iam_policy" "cnrm" {
  service_account_id = google_service_account.cnrm.name
  policy_data        = data.google_iam_policy.cnrm.policy_data
  depends_on         = [google_container_cluster.primary]
}

# CNRM Config Connector install
provider "helm" {
  kubernetes {
    host                   = google_container_cluster.primary.endpoint
    token                  = data.google_client_config.current.access_token
    client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

resource "helm_release" "cnrm" {
  name  = "gcp-config-connector"
  chart = "./charts/cnrm"

  set {
    name  = "serviceAccount"
    value = google_service_account.cnrm.email
  }
}
