# Jenkins Secret Text Credential Pattern

## Overview

Jenkins secret text credentials are added via a 3-step Terraform/JCasC pattern. No GCP Secret Manager is involved — secrets are passed as Terraform variables through Helm `additionalSecrets` and injected into JCasC.

## Step 1: Terraform Variable (`terraform/variables.tf`)

```terraform
variable "claude_code_oauth_token" {
  default     = ""
  description = "Claude Code OAuth token"
  type        = string
}
```

- Convention: snake_case variable names
- Always include a `description` and `default = ""`

## Step 2: Helm additionalSecrets (`terraform/jenkins.tf`, ~line 132)

```yaml
  - name: claude_code_oauth_token
    value: "${var.claude_code_oauth_token}"
```

- Name matches the Terraform variable name (snake_case)

## Step 3: JCasC Credential (`terraform/jenkins.tf`, ~line 200)

```yaml
              - string:
                  id: "claude-code-oauth-token"
                  secret: $${claude_code_oauth_token}
```

- Credential ID uses kebab-case (hyphens instead of underscores)
- `$${...}` syntax is Terraform-escaped template interpolation (single `$` would be interpreted by Terraform)

## Existing Examples

| Terraform Variable | JCasC Credential ID |
|--------------------|---------------------|
| `claude_code_oauth_token` | `claude-code-oauth-token` |
| `aws_ses_access_key_id` | `aws-ses-access-key-id` |
| `aws_ses_secret_access_key` | `aws-ses-secret-access-key` |
| `discord_webhook_url` | `discord-webhook-url` |
| `jira_api_key` | `jira-api-key` |
| `jenkins_api_key` | `jenkins-api-key` |

## For `claude_org_id`

Following the pattern:
- Terraform variable: `claude_org_id`
- additionalSecrets name: `claude_org_id`
- JCasC credential ID: `claude-org-id`
