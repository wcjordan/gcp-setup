variable "project_id" {
  default     = ""
  description = "ID of GCP project to install to"
}
variable "project_name" {
  default     = ""
  description = "Name of GCP project to install to"
}
variable "gcp_region" {
  default     = ""
  description = "Name of GCP region to use whenever relevant"
}
variable "gcp_zone" {
  default     = ""
  description = "Name of GCP zone to use whenever relevant"
}
variable "admin_email" {
  default     = ""
  description = "Email address of admin user.  Used for setting up Jenkins & giving admin permissions to OAuth account"
}
variable "dns_name" {
  default     = ""
  description = "DNS name to use"
}

variable "gcp_service_account_key" {
  default     = ""
  description = "The contents of a GCP service account key file in JSON format"
  type        = string
}

variable "github_app_id" {
  default     = ""
  description = "Github App ID for Jenkins to access Github"
  type        = string
}
variable "github_app_private_key" {
  default     = ""
  description = "Github App private key for Jenkins to access Github"
  type        = string
}

variable "browserstack_username" {
  default     = ""
  description = "BrowserStack username"
}
variable "browserstack_access_key" {
  default     = ""
  description = "BrowserStack access key"
}

variable "oauth_client_id" {
  default     = ""
  description = "OAuth client ID"
}
variable "oauth_client_secret" {
  default     = ""
  description = "OAuth client secret"
}

variable "sentry_dsn" {
  default     = ""
  description = "Sentry DSN used by Jenkins for CI deployments"
}
variable "sentry_token" {
  default     = ""
  description = "Sentry token used by Jenkins for CI deployments"
}

variable "chalk_oauth_client_secret" {
  default     = ""
  description = "The contents of an OAuth client secret in JSON format"
  type        = string
}
variable "chalk_oauth_refresh_token" {
  default     = ""
  description = "OAuth refresh token for CI Selenium tests for Chalk"
}
