# Implementation Plan: Add discord-webhook-url Credential to Jenkins

GH Issue: https://github.com/wcjordan/gcp-setup/issues/23

## Overview

Add a `discord-webhook-url` secret text credential to Jenkins by following the same pattern as existing credentials (`jenkins-api-key`, `claude-code-oauth-token`, etc.). Three files need to be changed: variable declaration, Helm additionalSecrets, and JCasC credentials config.

---

## Stage 1: Add discord-webhook-url credential to Jenkins

### Description

Add the `discord_webhook_url` secret text credential to Jenkins by making the following three changes to the Terraform configuration:

1. **`terraform/variables.tf`** — Add a new variable declaration:
   ```hcl
   variable "discord_webhook_url" {
     default     = ""
     description = "Discord webhook URL for notifications"
     type        = string
   }
   ```
   Place it alongside other secret variable declarations (e.g., after `jira_api_key`).

2. **`terraform/jenkins.tf` — `additionalSecrets` block** — Add an entry in the `controller.additionalSecrets` list inside the Helm release YAML:
   ```yaml
   - name: discord_webhook_url
     value: "${var.discord_webhook_url}"
   ```
   Add it after the `jira_api_key` entry.

3. **`terraform/jenkins.tf` — JCasC credentials block** — Add a `string` credential under `credentials.system.domainCredentials`:
   ```yaml
   - string:
       id: "discord-webhook-url"
       secret: ${discord_webhook_url}
   ```
   Add it after the `aws-ses-secret-access-key` credential entry (before the `usernamePassword` entry).

### Acceptance Criteria
- `terraform/variables.tf` contains a `discord_webhook_url` variable with `type = string` and a non-empty `description`.
- `terraform/jenkins.tf` `additionalSecrets` list includes an entry with `name: discord_webhook_url` referencing `var.discord_webhook_url`.
- `terraform/jenkins.tf` JCasC credentials block includes a `string` credential with `id: "discord-webhook-url"` and `secret: ${discord_webhook_url}`.
- The three changes follow the exact same style and ordering conventions as adjacent credentials.
- `terraform validate` (or equivalent lint) passes without errors.
