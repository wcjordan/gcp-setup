# Provisioning of misc GKE resources
resource "google_artifact_registry_repository" "primary" {
  repository_id = "${var.project_name}-gar"
  format        = "DOCKER"

  project       = "${var.project_id}"
  location      = "${var.gcp_region}"
}

resource "google_sql_database_instance" "shared-db" {
  name             = "${var.project_name}-shared-db"
  project          = "${var.project_id}"
  region           = "${var.gcp_region}"
  database_version = "POSTGRES_14"

  settings {
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    tier              = "db-f1-micro"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
    location_preference {
      zone = "${var.gcp_zone}"
    }
    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = true
    }
  }

  deletion_protection  = "true"
}
