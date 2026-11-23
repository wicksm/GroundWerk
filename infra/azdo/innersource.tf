# GroundWerk.InnerSource's packages (CODE-3, CODE-11): feed innersource holds them, and pipeline
# innersource-ci builds that repo from the ci template in GroundWerk.PipelineTemplates. Each PR
# build pushes its packages as prereleases, and each version tag's build pushes that version
# (CICD-13, docs/adr/0009).

# No upstream sources, so the feed holds only GroundWerk.InnerSource's own packages, and every
# other package comes straight from nuget.org through each repo's nuget.config
resource "azuredevops_feed" "innersource" {
  name       = "innersource"
  project_id = data.azuredevops_project.groundwerk.id
}

# The identity every pipeline in this project runs as, since each job's token is limited to the
# project. It's found by its account name, which is the project's ID, so renaming the project
# doesn't change it
data "azuredevops_identity_user" "build_service" {
  name          = data.azuredevops_project.groundwerk.id
  search_filter = "AccountName"
}

# Feed Publisher, so innersource-ci can push the packages and every pipeline can restore them
resource "azuredevops_feed_permission" "innersource_build_service" {
  feed_id             = azuredevops_feed.innersource.id
  project_id          = data.azuredevops_project.groundwerk.id
  role                = "contributor"
  identity_descriptor = data.azuredevops_identity_user.build_service.subject_descriptor
}

resource "azuredevops_build_definition" "innersource_ci" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "innersource-ci"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk.InnerSource"].id
    branch_name = "refs/heads/main"
    yml_path    = "pipelines/innersource-ci.yml"
  }

  ci_trigger {
    use_yaml = true
  }
}

# Lets pipeline innersource-ci use the SonarQube Cloud connection, registry-pull and the templates
# repo, as build-groundwerk does, so its first run doesn't wait for someone to permit them
resource "azuredevops_pipeline_authorization" "innersource_ci_sonarqube" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = data.azuredevops_serviceendpoint_sonarcloud.sonarqube_cloud.id
  pipeline_id = azuredevops_build_definition.innersource_ci.id
}

resource "azuredevops_pipeline_authorization" "innersource_ci_registry" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = azuredevops_serviceendpoint_azurecr.registry_pull.id
  pipeline_id = azuredevops_build_definition.innersource_ci.id
}

resource "azuredevops_pipeline_authorization" "innersource_ci_templates" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "repository"
  resource_id = azuredevops_git_repository.repo["GroundWerk.PipelineTemplates"].id
  pipeline_id = azuredevops_build_definition.innersource_ci.id
}
