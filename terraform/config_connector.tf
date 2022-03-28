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
resource "helm_release" "cnrm" {
  name  = "gcp-config-connector"
  chart = "charts/cnrm"

  replace      = true
  force_update = true

  set {
    name  = "serviceAccount"
    value = google_service_account.cnrm.email
  }
}
