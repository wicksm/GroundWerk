data "azuredevops_project" "groundwerk" {
  name = "GroundWerk"
}

locals {
  # Made by hand before this root existed: the one hand-made exception (IAC-12)
  hand_made_repos = toset(["GroundWerk", "GroundWerk.PipelineTemplates", "InnerSource"])

  # Every repo this root manages; later repos are added here, and Terraform creates them
  repos = local.hand_made_repos
}

import {
  for_each = local.hand_made_repos
  to       = azuredevops_git_repository.repo[each.key]
  id       = "GroundWerk/${each.key}"
}

resource "azuredevops_git_repository" "repo" {
  for_each   = local.repos
  project_id = data.azuredevops_project.groundwerk.id
  name       = each.key

  initialization {
    init_type = "Clean"
  }

  lifecycle {
    # Used only when a repo is created, so an imported repo always shows a difference here
    ignore_changes  = [initialization]
    prevent_destroy = true
  }
}