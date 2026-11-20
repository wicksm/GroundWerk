# Settings, a private repo that holds this environment's names, which the pipelines read through
# its variables template, so the repos that go public carry none of them (docs/adr/0012)
resource "azuredevops_git_repository" "settings" {
  project_id     = data.azuredevops_project.groundwerk.id
  name           = "Settings"
  default_branch = "refs/heads/main"

  # The first commit adds a README.md that holds only the project's name
  initialization {
    init_type = "Clean"
  }
}

# The repos Renovate updates, as project/repo
locals {
  renovate_repositories = [
    for name in sort(keys(azuredevops_git_repository.repo)) :
    "${data.azuredevops_project.groundwerk.name}/${name}"
  ]
}

# Its one file, on main. The next apply puts back any change made to it some other way.
resource "azuredevops_git_repository_file" "settings" {
  repository_id  = azuredevops_git_repository.settings.id
  branch         = azuredevops_git_repository.settings.default_branch
  file           = "variables.yml"
  commit_message = "Write the settings from infra/azdo"
  content        = <<-EOT
    # Written by infra/azdo/settings.tf, whose next apply puts back any other change. main has a
    # branch policy, which Terraform's identity may push past.
    variables:
      # The container registry's login server, from infra/azdo/registry.tf
      - name: registry
        value: ${azurerm_container_registry.registry.login_server}
      # The Managed DevOps Pool's name, from infra/azdo/pool.tf
      - name: pool
        value: ${azurerm_managed_devops_pool.pool.name}
      # The key of the SonarQube Cloud project that pipeline build-groundwerk analyzes
      - name: sonarProjectKey
        value: ${var.sonar_project_key}
      # The repos Renovate opens upgrade PRs in
      - name: renovateRepositories
        value: '${jsonencode(local.renovate_repositories)}'
  EOT

  # After main's policy and the permission to push past it, so that every apply can write the file
  depends_on = [
    azuredevops_branch_policy_min_reviewers.settings,
    azuredevops_group_membership.settings_writers,
    azuredevops_git_permissions.settings_writers,
  ]
}

# Contributors can read it but can't push to it, so its names change only through Terraform
data "azuredevops_group" "contributors" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "Contributors"
}

resource "azuredevops_git_permissions" "settings" {
  project_id    = data.azuredevops_project.groundwerk.id
  repository_id = azuredevops_git_repository.settings.id
  principal     = data.azuredevops_group.contributors.descriptor
  permissions = {
    CreateBranch      = "Deny"
    GenericContribute = "Deny"
  }
}

# An Only main check verifies that every repo a run reads has a branch policy, so Settings' main
# gets the other repos' reviewer policy (docs/adr/0012)
resource "azuredevops_branch_policy_min_reviewers" "settings" {
  project_id = azuredevops_git_repository.settings.project_id
  blocking   = true

  settings {
    reviewer_count             = 1
    submitter_can_vote         = false
    last_pusher_cannot_approve = true

    scope {
      repository_id  = azuredevops_git_repository.settings.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# Terraform writes variables.yml straight to main, so its identity, this group's one member, may
# push past the policy
resource "azuredevops_group" "settings_writers" {
  scope        = azuredevops_git_repository.settings.project_id
  display_name = "Settings Writers"
  description  = "Terraform's identity, which writes Settings' variables.yml past its main's policy"
}

resource "azuredevops_group_membership" "settings_writers" {
  group   = azuredevops_group.settings_writers.descriptor
  members = [azuredevops_service_principal_entitlement.azdo.descriptor]
  mode    = "overwrite" # Terraform made this group, so its members are exactly these
}

resource "azuredevops_git_permissions" "settings_writers" {
  project_id    = azuredevops_git_repository.settings.project_id
  repository_id = azuredevops_git_repository.settings.id
  principal     = azuredevops_group.settings_writers.descriptor
  permissions = {
    PolicyExempt = "Allow" # Bypass policies when pushing
  }
}

# The pipelines that read it, so their first run doesn't wait for someone to permit it. A pipeline
# that starts reading Settings needs an entry here.
resource "azuredevops_pipeline_authorization" "settings" {
  for_each = {
    ai_developer     = azuredevops_build_definition.ai_developer.id
    build_groundwerk = azuredevops_build_definition.build_groundwerk.id
    innersource_ci   = azuredevops_build_definition.innersource_ci.id
    renovate         = azuredevops_build_definition.renovate.id
  }

  project_id  = data.azuredevops_project.groundwerk.id
  type        = "repository"
  resource_id = azuredevops_git_repository.settings.id
  pipeline_id = each.value
}
