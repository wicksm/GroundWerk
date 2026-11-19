# main's branch policy on every repo, the SOC 2 evidence (SDLC-5).
# The PR builds of GroundWerk and InnerSource join it at the end of this file.

resource "azuredevops_branch_policy_min_reviewers" "main" {
  for_each   = azuredevops_git_repository.repo
  project_id = data.azuredevops_project.groundwerk.id
  blocking   = true

  settings {
    reviewer_count             = 1
    submitter_can_vote         = false
    last_pusher_cannot_approve = true

    scope {
      repository_id  = each.value.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_work_item_linking" "main" {
  for_each   = azuredevops_git_repository.repo
  project_id = data.azuredevops_project.groundwerk.id
  blocking   = true

  settings {
    scope {
      repository_id  = each.value.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_comment_resolution" "main" {
  for_each   = azuredevops_git_repository.repo
  project_id = data.azuredevops_project.groundwerk.id
  blocking   = true

  settings {
    scope {
      repository_id  = each.value.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# Squash merges only (SDLC-8)
resource "azuredevops_branch_policy_merge_types" "main" {
  for_each   = azuredevops_git_repository.repo
  project_id = data.azuredevops_project.groundwerk.id
  blocking   = true

  settings {
    allow_squash                  = true
    allow_basic_no_fast_forward   = false
    allow_rebase_and_fast_forward = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = each.value.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# GroundWerk's PR build: pipeline build-groundwerk has to pass on the PR's merge for any change
# outside docs and Markdown files (CICD-10, GATE-1, GATE-6, docs/adr/0008)
resource "azuredevops_branch_policy_build_validation" "build_groundwerk" {
  project_id = data.azuredevops_project.groundwerk.id
  blocking   = true

  settings {
    display_name        = "build-groundwerk"
    build_definition_id = azuredevops_build_definition.build_groundwerk.id
    filename_patterns   = ["/*", "!/docs/*", "!*.md"]

    scope {
      repository_id  = azuredevops_git_repository.repo["GroundWerk"].id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# InnerSource's PR build: pipeline innersource-ci has to pass on the PR's merge for any change
# outside Markdown files (CICD-10, CICD-13, GATE-1, GATE-6, docs/adr/0009)
resource "azuredevops_branch_policy_build_validation" "innersource_ci" {
  project_id = data.azuredevops_project.groundwerk.id
  blocking   = true

  settings {
    display_name        = "innersource-ci"
    build_definition_id = azuredevops_build_definition.innersource_ci.id
    filename_patterns   = ["/*", "!*.md"]

    scope {
      repository_id  = azuredevops_git_repository.repo["InnerSource"].id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}
