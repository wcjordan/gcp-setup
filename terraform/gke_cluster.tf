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
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  addons_config {
    config_connector_config {
      enabled = true
    }
  }

  # Enables VPC native cluster routing
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/14"
    services_ipv4_cidr_block = "/20"
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
    machine_type = "e2-standard-4"
    spot         = true

    tags     = ["gke-node", "${var.project_name}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
    labels   = {
      env = var.project_name
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
    shielded_instance_config {
      enable_secure_boot = true
    }

    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io"
  version    = "4.2.5"

  # Wait for node pool to exist before installing nginx controller to avoid a timeout
  depends_on = [google_container_node_pool.primary_nodes]
}
