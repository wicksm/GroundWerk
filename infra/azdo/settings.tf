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
    # Written by infra/azdo/settings.tf, whose next apply puts back any other change
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
