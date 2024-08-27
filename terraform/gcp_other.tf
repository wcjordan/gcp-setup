# Provisioning of misc GKE resources
resource "google_artifact_registry_repository" "primary" {
  repository_id = "${var.project_name}-gar"
  format        = "DOCKER"

  project       = "${var.project_id}"
  location      = "${var.gcp_region}"

  cleanup_policies {
    id     = "Delete older than 90 days"
    action = "DELETE"
    condition {
      older_than = "7776000s"
    }
  }
  cleanup_policies {
    id     = "Keep last 10"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
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
      backup_retention_settings {
        retention_unit = "COUNT"
        retained_backups = 30
      }
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

resource "google_dns_managed_zone" "parent-zone" {
  name        = "${var.project_name}-dns"
  dns_name    = "${var.dns_name}."
  description = "Top level DNS zone for ${var.project_name}."
}

# Storage bucket for capturing web session data
resource "google_storage_bucket" "gcf_source" {
  name                        = "flipperkid-chalk-web-session-data"
  location                    = "US"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}