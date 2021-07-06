# TODO (jordan) Setup workload identity

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
  }

  required_version = ">= 1.0.1"
}

provider "google" {
  credentials = file("service_account_key.json")

  project = var.project_id
  region  = "us-east4"
  zone    = "us-east4-c"
}

data "google_client_config" "this" {}

# GKE service account
resource "google_service_account" "default" {
  account_id   = "${var.project_name}-gke-sa-id"
  display_name = "${var.project_name}-gke-sa"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name = "${var.project_name}-gke"

  enable_shielded_nodes = true
  release_channel {
    channel = "RAPID"
  }
  workload_identity_config {
    identity_namespace = "${data.google_client_config.this.project}.svc.id.goog"
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
  name               = "${var.project_name}-gke-node-pool"
  cluster            = google_container_cluster.primary.name
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

    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}
