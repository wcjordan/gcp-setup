# Implementation Plan: Add `claude_org_id` Secret to Jenkins

**Epic:** minordomo-1tk
**GH Issue:** https://github.com/wcjordan/gcp-setup/issues/34

## Background

Add a new `claude_org_id` secret text credential to Jenkins following the established pattern used for `claude_code_oauth_token`, `aws_ses_secret_access_key`, `discord_webhook_url`, and other secrets. The pattern involves three files: `terraform/variables.tf`, and two locations in `terraform/jenkins.tf`.

---

## Stage 1: Add claude_org_id Terraform variable and Jenkins credential

### Description

Add the `claude_org_id` secret to Jenkins by following the established 3-step pattern:

1. Add a Terraform variable `claude_org_id` to `terraform/variables.tf` (following the same structure as `claude_code_oauth_token` directly above it).
2. Add the secret to the `additionalSecrets` list in `terraform/jenkins.tf` (in the Helm values block around line 143–152).
3. Add a JCasC `string` credential entry in `terraform/jenkins.tf` (in the JCasC configScripts block around line 206–216).

**Specific changes:**

**`terraform/variables.tf`** — add after `discord_webhook_url` block (~line 98):
```terraform
variable "claude_org_id" {
  default     = ""
  description = "Claude organization ID"
  type        = string
}
```

**`terraform/jenkins.tf`** — add to `additionalSecrets` list after `discord_webhook_url` entry (~line 152):
```yaml
  - name: claude_org_id
    value: "${var.claude_org_id}"
```

**`terraform/jenkins.tf`** — add to JCasC credentials list after `discord-webhook-url` entry (~line 216):
```yaml
              - string:
                  id: "claude-org-id"
                  secret: $${claude_org_id}
```

### Acceptance Criteria
- `terraform/variables.tf` contains a `claude_org_id` variable with `default = ""`, a description, and `type = string`
- `terraform/jenkins.tf` `additionalSecrets` list includes an entry with `name: claude_org_id` and `value: "${var.claude_org_id}"`
- `terraform/jenkins.tf` JCasC credentials list includes a `string` credential with `id: "claude-org-id"` and `secret: $${claude_org_id}`
- `terraform validate` passes (or equivalent lint if available)
- No other files are modified
