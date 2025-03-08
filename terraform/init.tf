terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
  }

  required_version = ">= 1.9.7"
}

provider "google" {
  credentials = var.gcp_service_account_key

  project = var.project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

provider "kubectl" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.current.access_token
  client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  load_config_file       = "false"
}

provider "kubernetes" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.current.access_token
  client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
  client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = google_container_cluster.primary.endpoint
    token                  = data.google_client_config.current.access_token
    client_certificate     = base64decode(google_container_cluster.primary.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.primary.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

data "google_client_config" "current" {}
