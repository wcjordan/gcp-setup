# Research: minordomo-xf8 — Add discord_bot_token and DISCORD_CHANNEL_ID to Jenkins

## Task
Add `discord_bot_token` secret text credential and `DISCORD_CHANNEL_ID` env variable to Jenkins.

## Pattern (from existing credentials like `claude_org_id`, `discord_webhook_url`)

### `terraform/variables.tf`
Each secret/env value has a corresponding Terraform variable with `default = ""`, a description, and `type = string`.

Recent examples:
- `discord_webhook_url` (line 94–98)
- `claude_org_id` (line 100–104)
- `jira_cloud_id` (line 106–110) — used as env var, not a secret

### `terraform/jenkins.tf` — Three locations to update

1. **`controller.additionalSecrets`** (lines 133–154 in Helm values YAML block):
   Each secret is listed as `- name: <snake_case>\n    value: "${var.<snake_case>}"`.

2. **JCasC credentials section** (lines 188–225):
   Secret text credentials use:
   ```yaml
   - string:
       id: "<kebab-case>"
       secret: $${<snake_case>}
   ```

3. **`globalNodeProperties.envVars.env`** (lines 243–251):
   Env vars use:
   ```yaml
   - key: "UPPER_SNAKE_CASE"
     value: "${var.<snake_case>}"
   ```
   Example: `ROOT_DOMAIN` from `var.dns_name`, `JIRA_CLOUD_ID` from `var.jira_cloud_id`.

## Changes Required

### `terraform/variables.tf`
- Add `discord_bot_token` variable (secret)
- Add `discord_channel_id` variable (env var value)

### `terraform/jenkins.tf`
- Add `discord_bot_token` to `additionalSecrets`
- Add `discord-bot-token` string credential to JCasC credentials
- Add `DISCORD_CHANNEL_ID` env var to `globalNodeProperties.envVars.env`
- Add `discord_channel_id` to `additionalSecrets`? No — env vars use `var.` directly in the value, not via additionalSecrets. See how `ROOT_DOMAIN` uses `var.dns_name` directly.
