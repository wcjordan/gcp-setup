# Provisioning of misc GKE resources
resource "google_artifact_registry_repository" "primary" {
  repository_id = "${var.project_name}-gar"
  format        = "DOCKER"

  project       = "${var.project_id}"
}
