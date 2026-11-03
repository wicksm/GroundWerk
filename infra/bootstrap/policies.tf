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

# Squash merges only, as at Avid (SDLC-8)
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