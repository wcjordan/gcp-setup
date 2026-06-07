# Implementation Plan: Add discord_bot_token and DISCORD_CHANNEL_ID to Jenkins

## Stage 1: Add discord_bot_token secret and DISCORD_CHANNEL_ID env var to Terraform Jenkins config

### Description
Add the `discord_bot_token` secret text credential and `DISCORD_CHANNEL_ID` global environment variable to the Jenkins Terraform configuration, following the same pattern used for `claude_org_id`, `discord_webhook_url`, and `JIRA_CLOUD_ID`.

Changes required:

**`terraform/variables.tf`:**
- Add `discord_bot_token` variable (type string, empty default, description "Discord bot token")
- Add `discord_channel_id` variable (type string, empty default, description "Discord channel ID for notifications")

**`terraform/jenkins.tf`:**
- In `controller.additionalSecrets`, add entry for `discord_bot_token` (value from `var.discord_bot_token`)
- In JCasC `credentials.system.domainCredentials[].credentials[]`, add a `string` credential with `id: "discord-bot-token"` and `secret: $${discord_bot_token}`
- In `globalNodeProperties.envVars.env`, add `DISCORD_CHANNEL_ID` with `value: "${var.discord_channel_id}"`

### Acceptance Criteria
- `terraform/variables.tf` contains a `discord_bot_token` variable with `type = string` and `default = ""`
- `terraform/variables.tf` contains a `discord_channel_id` variable with `type = string` and `default = ""`
- `terraform/jenkins.tf` `additionalSecrets` list includes `discord_bot_token` referencing `var.discord_bot_token`
- `terraform/jenkins.tf` JCasC credentials include a `string` credential with `id: "discord-bot-token"`
- `terraform/jenkins.tf` global env vars include `DISCORD_CHANNEL_ID` referencing `var.discord_channel_id`
- All existing credentials and env vars are preserved unchanged
