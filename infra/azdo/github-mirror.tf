# Pipeline mirror-to-github (GATE-6, GATE-12), which copies main and the tags of each of the
# project's repos but Settings to its copy on GitHub, every day and whenever you run it, both from
# main. It has no CI trigger, so no push can start it, whatever the pushed branch's copy of its YAML
# says. Each GitHub repo's deploy key is a secure file with an Only main check, both made by hand
# since this provider can't make or find secure files, and its first run waits until someone
# permits it to use them (docs/adr/0013).
resource "azuredevops_build_definition" "github_mirror" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "mirror-to-github"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk"].id
    branch_name = "refs/heads/main"
    yml_path    = "pipelines/mirror-to-github.yml"
  }

  # Its variables GITHUB_OWNER, GITHUB_NOREPLY, PRIVATE_WORDS and PRIVATE_RENAMES, the GitHub
  # account, its no-reply address, the words that must never reach GitHub and the renames that take
  # them out of the history, are set by hand, so no repo names them
  lifecycle {
    ignore_changes = [variable]
  }
}

# Lets it check out the other two repos, so its first run doesn't wait for someone to permit them
resource "azuredevops_pipeline_authorization" "github_mirror_templates" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "repository"
  resource_id = azuredevops_git_repository.repo["GroundWerk.PipelineTemplates"].id
  pipeline_id = azuredevops_build_definition.github_mirror.id
}

resource "azuredevops_pipeline_authorization" "github_mirror_innersource" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "repository"
  resource_id = azuredevops_git_repository.repo["GroundWerk.InnerSource"].id
  pipeline_id = azuredevops_build_definition.github_mirror.id
}
