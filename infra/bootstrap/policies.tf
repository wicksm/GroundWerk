# main's branch policy on every repo, the SOC 2 evidence (SDLC-5).
# The green PR build joins it once the first pipeline exists.

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