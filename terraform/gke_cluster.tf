# GKE cluster
resource "google_container_cluster" "primary" {
  name = "${var.project_name}-gke"
  location = "${var.gcp_zone}"

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
  location = "${var.gcp_zone}"

  initial_node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "e2-standard-4"
    spot         = true
    disk_size_gb = 25
    disk_type    = "pd-standard"

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

    # Needed to avoid an error w/ no content updates.  Try removing next time you update this nodepool.
    kubelet_config {
      cpu_manager_policy = ""
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform.read-only",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "kubectl_manifest" "https_redirect" {
    yaml_body = <<YAML
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: https_redirect
spec:
  redirectToHttps:
    enabled: true
YAML

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "helm_release" "cert-manager" {
  name              = "cert-manager"
  chart             = "cert-manager"
  repository        = "https://charts.jetstack.io"
  version           = "v1.17.1"
  namespace         = "cert-manager"
  create_namespace  = "true"
  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubectl_manifest" "cert-issuer" {
    yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-cluster-cert-issuer
spec:
  acme:
    email: ${var.admin_email}
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-cluster-cert-issuer-private-key
    solvers:
    - http01:
        ingress:
          ingressClassName: nginx
YAML

  depends_on = [google_container_node_pool.primary_nodes]
}

resource "kubernetes_annotations" "default-namespace-annotation" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = "default"
  }
  annotations = {
    "cnrm.cloud.google.com/project-id" = var.project_id
  }
}
resource "kubernetes_namespace" "dev-namespace" {
  metadata {
    name = "dev"
    annotations = {
      "cnrm.cloud.google.com/project-id" = var.project_id
    }
  }
}
resource "kubernetes_namespace" "test-namespace" {
  metadata {
    name = "test"
    annotations = {
      "cnrm.cloud.google.com/project-id" = var.project_id
    }
  }
}
resource "kubernetes_namespace" "prod-namespace" {
  metadata {
    name = "prod"
    annotations = {
      "cnrm.cloud.google.com/project-id" = var.project_id
    }
  }
}
