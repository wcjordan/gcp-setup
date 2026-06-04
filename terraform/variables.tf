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

variable "jenkins_api_key" {
  default     = ""
  description = "Jenkins API key"
  type        = string
}
variable "claude_code_oauth_token" {
  default     = ""
  description = "Claude Code OAuth token"
  type        = string
}

variable "aws_ses_access_key_id" {
  default     = ""
  description = "AWS SES access key ID"
  type        = string
}
variable "aws_ses_secret_access_key" {
  default     = ""
  description = "AWS SES secret access key"
  type        = string
}

variable "jira_api_username" {
  default     = ""
  description = "Jira API username"
  type        = string
}
variable "jira_api_key" {
  default     = ""
  description = "Jira API key (password)"
  type        = string
}

variable "discord_webhook_url" {
  default     = ""
  description = "Discord webhook URL for notifications"
  type        = string
}

variable "claude_org_id" {
  default     = ""
  description = "Claude organization ID"
  type        = string
}

variable "jira_cloud_id" {
  default     = ""
  description = "Jira Cloud ID"
  type        = string
}
