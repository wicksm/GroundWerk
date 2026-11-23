# The repos' keys are their names, so story 63's new names moved each repo, and the branch
# policies and Renovate's permissions made for each one, to a new key. These blocks tell Terraform
# they're the same resources, so it renames each repo in place instead of destroying it and making
# a new one. The story's next PR in this repo deletes this file once azdo-terraform has applied it.
moved {
  from = azuredevops_git_repository.repo["GroundWerk"]
  to   = azuredevops_git_repository.repo["GroundWerk"]
}

moved {
  from = azuredevops_git_repository.repo["GroundWerk.PipelineTemplates"]
  to   = azuredevops_git_repository.repo["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_git_repository.repo["InnerSource"]
  to   = azuredevops_git_repository.repo["GroundWerk.InnerSource"]
}

moved {
  from = azuredevops_branch_policy_min_reviewers.main["GroundWerk"]
  to   = azuredevops_branch_policy_min_reviewers.main["GroundWerk"]
}

moved {
  from = azuredevops_branch_policy_min_reviewers.main["GroundWerk.PipelineTemplates"]
  to   = azuredevops_branch_policy_min_reviewers.main["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_branch_policy_min_reviewers.main["InnerSource"]
  to   = azuredevops_branch_policy_min_reviewers.main["GroundWerk.InnerSource"]
}

moved {
  from = azuredevops_branch_policy_work_item_linking.main["GroundWerk"]
  to   = azuredevops_branch_policy_work_item_linking.main["GroundWerk"]
}

moved {
  from = azuredevops_branch_policy_work_item_linking.main["GroundWerk.PipelineTemplates"]
  to   = azuredevops_branch_policy_work_item_linking.main["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_branch_policy_work_item_linking.main["InnerSource"]
  to   = azuredevops_branch_policy_work_item_linking.main["GroundWerk.InnerSource"]
}

moved {
  from = azuredevops_branch_policy_comment_resolution.main["GroundWerk"]
  to   = azuredevops_branch_policy_comment_resolution.main["GroundWerk"]
}

moved {
  from = azuredevops_branch_policy_comment_resolution.main["GroundWerk.PipelineTemplates"]
  to   = azuredevops_branch_policy_comment_resolution.main["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_branch_policy_comment_resolution.main["InnerSource"]
  to   = azuredevops_branch_policy_comment_resolution.main["GroundWerk.InnerSource"]
}

moved {
  from = azuredevops_branch_policy_merge_types.main["GroundWerk"]
  to   = azuredevops_branch_policy_merge_types.main["GroundWerk"]
}

moved {
  from = azuredevops_branch_policy_merge_types.main["GroundWerk.PipelineTemplates"]
  to   = azuredevops_branch_policy_merge_types.main["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_branch_policy_merge_types.main["InnerSource"]
  to   = azuredevops_branch_policy_merge_types.main["GroundWerk.InnerSource"]
}

moved {
  from = azuredevops_git_permissions.renovate["GroundWerk"]
  to   = azuredevops_git_permissions.renovate["GroundWerk"]
}

moved {
  from = azuredevops_git_permissions.renovate["GroundWerk.PipelineTemplates"]
  to   = azuredevops_git_permissions.renovate["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_git_permissions.renovate["InnerSource"]
  to   = azuredevops_git_permissions.renovate["GroundWerk.InnerSource"]
}

moved {
  from = azuredevops_git_permissions.renovate_main["GroundWerk"]
  to   = azuredevops_git_permissions.renovate_main["GroundWerk"]
}

moved {
  from = azuredevops_git_permissions.renovate_main["GroundWerk.PipelineTemplates"]
  to   = azuredevops_git_permissions.renovate_main["GroundWerk.PipelineTemplates"]
}

moved {
  from = azuredevops_git_permissions.renovate_main["InnerSource"]
  to   = azuredevops_git_permissions.renovate_main["GroundWerk.InnerSource"]
}
