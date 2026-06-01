# Research: minordomo-167 — Add discord-webhook-url credential to Jenkins

## How Secret Text Credentials Are Added

All secret text ("string") credentials in Jenkins follow the same three-location pattern:

### 1. Terraform variable (`terraform/variables.tf`)

Each secret is declared as a variable:
```hcl
variable "discord_webhook_url" {
  default     = ""
  description = "Discord webhook URL for notifications"
  type        = string
}
```

### 2. Helm `additionalSecrets` block (`terraform/jenkins.tf`)

The value is passed into the Jenkins helm chart as an additional secret, so JCasC can reference it via `${}` interpolation:
```yaml
controller:
  additionalSecrets:
  - name: discord_webhook_url
    value: "${var.discord_webhook_url}"
```

Existing examples: `jenkins_api_key`, `claude_code_oauth_token`, `aws_ses_access_key_id`, `aws_ses_secret_access_key`, `jira_api_key`.

### 3. JCasC credentials block (`terraform/jenkins.tf`)

A `string` credential entry is added under the `credentials.system.domainCredentials` list:
```yaml
- string:
    id: "discord-webhook-url"
    secret: ${discord_webhook_url}
```

Existing examples in the same block: `jenkins-api-key`, `claude-code-oauth-token`, `aws-ses-access-key-id`, `aws-ses-secret-access-key`.

## Files to Modify

- `terraform/variables.tf` — add variable declaration
- `terraform/jenkins.tf` — add to `additionalSecrets` and JCasC `credentials` block
