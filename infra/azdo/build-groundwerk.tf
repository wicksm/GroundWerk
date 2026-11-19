# Pipeline build-groundwerk, GroundWerk's build (CICD-3). It extends the ci template from
# GroundWerk.PipelineTemplates, pinned to a release tag (CICD-1), and runs on each change to main
# and as main's PR build (policies.tf), in the image from registry.tf (docs/adr/0008).
resource "azuredevops_build_definition" "build_groundwerk" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "build-groundwerk"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk"].id
    branch_name = "refs/heads/main"
    yml_path    = "pipelines/build-groundwerk.yml"
  }

  ci_trigger {
    use_yaml = true
  }
}

# The SonarQube Cloud connection you made by hand, with sonarqube-ci's token, so the token never
# reaches Terraform's state. PR builds use it, so it has no Only main check (docs/adr/0008).
data "azuredevops_serviceendpoint_sonarcloud" "sonarqube_cloud" {
  project_id            = data.azuredevops_project.groundwerk.id
  service_endpoint_name = "sonarqube-cloud"
}

# Lets pipeline build-groundwerk use the SonarQube Cloud connection, registry-pull and the templates
# repo, so its first run doesn't wait for someone to permit them
resource "azuredevops_pipeline_authorization" "build_groundwerk_sonarqube" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = data.azuredevops_serviceendpoint_sonarcloud.sonarqube_cloud.id
  pipeline_id = azuredevops_build_definition.build_groundwerk.id
}

resource "azuredevops_pipeline_authorization" "build_groundwerk_registry" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = azuredevops_serviceendpoint_azurecr.registry_pull.id
  pipeline_id = azuredevops_build_definition.build_groundwerk.id
}

resource "azuredevops_pipeline_authorization" "build_groundwerk_templates" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "repository"
  resource_id = azuredevops_git_repository.repo["GroundWerk.PipelineTemplates"].id
  pipeline_id = azuredevops_build_definition.build_groundwerk.id
}
