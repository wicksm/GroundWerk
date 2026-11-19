# The pipeline's Terraform labels became build_groundwerk in story 61, so Terraform moves its
# definition, authorizations and PR build policy in its state instead of destroying and recreating
# them. The story's second PR deletes this file once azdo-terraform has applied it.
moved {
  from = azuredevops_build_definition.groundwerk_ci
  to   = azuredevops_build_definition.build_groundwerk
}

moved {
  from = azuredevops_pipeline_authorization.groundwerk_ci_sonarqube
  to   = azuredevops_pipeline_authorization.build_groundwerk_sonarqube
}

moved {
  from = azuredevops_pipeline_authorization.groundwerk_ci_registry
  to   = azuredevops_pipeline_authorization.build_groundwerk_registry
}

moved {
  from = azuredevops_pipeline_authorization.groundwerk_ci_templates
  to   = azuredevops_pipeline_authorization.build_groundwerk_templates
}

moved {
  from = azuredevops_branch_policy_build_validation.groundwerk_ci
  to   = azuredevops_branch_policy_build_validation.build_groundwerk
}
