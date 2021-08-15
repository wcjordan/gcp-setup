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
  description = "Email address of admin.  Used for setting up Jenkins & giving adming permissions to OAuth account"
}
variable "dns_name" {
  default     = ""
  description = "DNS name to use"
}

variable "google_service_account_key" {
  default     = ""
  description = "Service account key for using GKE"
}

variable "browserstack_username" {
  default     = ""
  description = "BrowserStack username"
}
variable "browserstack_id" {
  default     = ""
  description = "BrowserStack ID"
}
variable "browserstack_access_key" {
  default     = ""
  description = "BrowserStack Access Key"
}

variable "oauth_client_id" {
  default     = ""
  description = "OAuth Client ID"
}
variable "oauth_client_secret" {
  default     = ""
  description = "OAuth Client Secret"
}
