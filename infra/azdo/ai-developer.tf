# The AI developer (AI-5): a Claude Agent SDK program in tools/ai-developer that takes one user
# story or bug to one PR, run by pipeline ai-developer. It signs in as groundwerk-ai-developer
# through the ai-developer service connection, which you make by hand, since this provider can't
# make that type yet. It can create branches and open PRs, and it can't push to main or to anyone
# else's branch, complete a PR, run a pipeline or reach a secret (ADR 0006).

# The audience the AI developer asks Entra ID for a Claude API token for, which Anthropic's
# workload identity federation exchanges for Claude API access in place of an API key.
# groundwerk-azdo becomes the registration's owner when it creates it.
resource "azuread_application_registration" "claude_api_audience" {
  display_name                   = "claude-api-audience"
  requested_access_token_version = 2
}

resource "azuread_application_identifier_uri" "claude_api_audience" {
  application_id = azuread_application_registration.claude_api_audience.id
  identifier_uri = "api://${azuread_application_registration.claude_api_audience.client_id}"
}

# Entra ID issues tokens only for an audience with a service principal in the tenant
resource "azuread_service_principal" "claude_api_audience" {
  client_id = azuread_application_registration.claude_api_audience.client_id
  owners    = [azuread_service_principal.azdo.object_id]
}

# Azure DevOps grants these permissions only to groups, so the AI developer has a group of its
# own, which reads the project like any Reader
resource "azuredevops_group" "ai_developers" {
  scope        = data.azuredevops_project.groundwerk.id
  display_name = "AI Developers"
  description  = "Agents that create branches and open PRs, and can't push to main (AI-5)"
}

resource "azuredevops_group_membership" "ai_developers" {
  group   = azuredevops_group.ai_developers.descriptor
  members = [azuredevops_service_principal_entitlement.ai_developer.descriptor]
  mode    = "overwrite" # Terraform made this group, so its members are exactly these
}

resource "azuredevops_group_membership" "ai_developers_read" {
  group   = data.azuredevops_group.groundwerk_readers.descriptor
  members = [azuredevops_group.ai_developers.descriptor]
  mode    = "add"
}

# In GroundWerk it creates its own branches and opens PRs. A branch's creator gets Contribute
# on that branch alone, so it pushes only to branches it made.
resource "azuredevops_git_permissions" "ai_developers" {
  project_id    = data.azuredevops_project.groundwerk.id
  repository_id = azuredevops_git_repository.repo["GroundWerk"].id
  principal     = azuredevops_group.ai_developers.descriptor
  permissions = {
    CreateBranch          = "Allow"
    PullRequestContribute = "Allow"
  }
}

# main denies it too, so it can't push there or complete a PR into it, and you complete its PRs
resource "azuredevops_git_permissions" "ai_developers_main" {
  project_id    = data.azuredevops_project.groundwerk.id
  repository_id = azuredevops_git_repository.repo["GroundWerk"].id
  branch_name   = "refs/heads/main"
  principal     = azuredevops_group.ai_developers.descriptor
  permissions = {
    GenericContribute = "Deny"
  }
}

# Linking a PR to its work item needs Edit work items, which Readers don't have
resource "azuredevops_area_permissions" "ai_developers" {
  project_id = data.azuredevops_project.groundwerk.id
  principal  = azuredevops_group.ai_developers.descriptor
  path       = "/"
  permissions = {
    WORK_ITEM_WRITE = "Allow"
  }
}

# The pipeline, which you run by hand. It has no CI trigger, so no push can start it, whatever
# the pushed branch's copy of its YAML says.
resource "azuredevops_build_definition" "ai_developer" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "ai-developer"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk"].id
    branch_name = "refs/heads/main"
    yml_path    = "pipelines/ai-developer.yml"
  }

  variable {
    name           = "CLAUDE_TOKEN_AUDIENCE"
    value          = azuread_application_identifier_uri.claude_api_audience.identifier_uri
    allow_override = false
  }

  lifecycle {
    # The Console's four IDs are variables you add by hand
    ignore_changes = [variable]
  }
}

# The service connection you made by hand
data "azuredevops_serviceendpoint_generic_v2" "ai_developer" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "ai-developer"
}

# Only a run from main may use the connection, so a branch can't borrow it
resource "azuredevops_check_branch_control" "ai_developer_connection" {
  project_id               = data.azuredevops_project.groundwerk.id
  display_name             = "Only main"
  target_resource_id       = data.azuredevops_serviceendpoint_generic_v2.ai_developer.id
  target_resource_type     = "endpoint"
  allowed_branches         = "refs/heads/main"
  verify_branch_protection = true
}

# Only this pipeline may use the connection
resource "azuredevops_pipeline_authorization" "ai_developer_connection" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = data.azuredevops_serviceendpoint_generic_v2.ai_developer.id
  pipeline_id = azuredevops_build_definition.ai_developer.id
}
