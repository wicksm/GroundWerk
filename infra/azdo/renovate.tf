# Renovate (CICD-17), which opens upgrade PRs in the project's repos as groundwerk-renovate,
# whose identity and seat are in identities.tf and azdo-access.tf. It can create branches and open
# PRs, and it can't push to main or to anyone else's branch, complete a PR or reach a secret
# (docs/adr/0010).

# Azure DevOps grants these permissions only to groups, so Renovate has a group of its own, which
# reads the project like any Reader
resource "azuredevops_group" "renovate" {
  scope        = data.azuredevops_project.groundwerk.id
  display_name = "Renovate"
  description  = "Renovate, which opens upgrade PRs and can't push to main (CICD-17)"
}

resource "azuredevops_group_membership" "renovate" {
  group   = azuredevops_group.renovate.descriptor
  members = [azuredevops_service_principal_entitlement.renovate.descriptor]
  mode    = "overwrite" # Terraform made this group, so its members are exactly these
}

resource "azuredevops_group_membership" "renovate_read" {
  group   = data.azuredevops_group.groundwerk_readers.descriptor
  members = [azuredevops_group.renovate.descriptor]
  mode    = "add"
}

# In each repo it creates its own branches and opens PRs. A branch's creator gets Contribute on
# that branch alone, so it pushes only to branches it made.
resource "azuredevops_git_permissions" "renovate" {
  for_each      = azuredevops_git_repository.repo
  project_id    = data.azuredevops_project.groundwerk.id
  repository_id = each.value.id
  principal     = azuredevops_group.renovate.descriptor
  permissions = {
    CreateBranch          = "Allow"
    PullRequestContribute = "Allow"
  }
}

# main denies it too, so it can't push there or complete a PR into it, and a person completes its
# PRs
resource "azuredevops_git_permissions" "renovate_main" {
  for_each      = azuredevops_git_repository.repo
  project_id    = data.azuredevops_project.groundwerk.id
  repository_id = each.value.id
  branch_name   = "refs/heads/main"
  principal     = azuredevops_group.renovate.descriptor
  permissions = {
    GenericContribute = "Deny"
  }
}

# It reads the innersource feed to find GroundWerk.InnerSource's new versions
resource "azuredevops_feed_permission" "innersource_renovate" {
  feed_id             = azuredevops_feed.innersource.id
  project_id          = data.azuredevops_project.groundwerk.id
  role                = "reader"
  identity_descriptor = azuredevops_group.renovate.descriptor
}

# Each of its PRs links Feature 21, "Upgrades open their own PRs", in area Platform, and linking
# needs Edit work items there, which Readers don't have
resource "azuredevops_area_permissions" "renovate" {
  project_id = data.azuredevops_project.groundwerk.id
  principal  = azuredevops_group.renovate.descriptor
  path       = "/Platform"
  permissions = {
    WORK_ITEM_WRITE = "Allow"
  }
}

# The pipeline, which runs Renovate on its schedule and when you run it, both from main. It has no
# CI trigger, so no push can start it, whatever the pushed branch's copy of its YAML says.
resource "azuredevops_build_definition" "renovate" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "run-renovate"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk"].id
    branch_name = "refs/heads/main"
    yml_path    = "pipelines/run-renovate.yml"
  }
}

# The service connection you made by hand, since this provider can't make that type yet
data "azuredevops_serviceendpoint_generic_v2" "renovate" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "renovate"
}

# Only a run from main may use the connection, so a branch can't borrow it
resource "azuredevops_check_branch_control" "renovate_connection" {
  project_id               = data.azuredevops_project.groundwerk.id
  display_name             = "Only main"
  target_resource_id       = data.azuredevops_serviceendpoint_generic_v2.renovate.id
  target_resource_type     = "endpoint"
  allowed_branches         = "refs/heads/main"
  verify_branch_protection = true
}

# Only this pipeline may use the connection
resource "azuredevops_pipeline_authorization" "renovate_connection" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = data.azuredevops_serviceendpoint_generic_v2.renovate.id
  pipeline_id = azuredevops_build_definition.renovate.id
}
