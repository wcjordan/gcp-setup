variable "project_id" {
  default     = ""
  description = "ID of GCP project to install to"
}
variable "project_name" {
  default     = ""
  description = "Name of GCP project to install to"
}
variable "admin_email" {
  default     = ""
  description = "Email address of admin user.  Used for setting up Jenkins & giving admin permissions to OAuth account"
}
variable "dns_name" {
  default     = ""
  description = "DNS name to use"
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
