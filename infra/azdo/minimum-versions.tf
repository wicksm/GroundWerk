# The minimum versions of packages that builds must reach (CICD-17). From v1.2.0, the ci template
# in GroundWerk.PipelineTemplates reads variable group minimum-versions in every build: a build
# that uses a package below its minimum warns until the deadline, and fails from that day on, in
# UTC. To announce a minimum, add an entry here through a PR, such as
# { package = "InnerSource.Telemetry", minimum = "1.1.0", deadline = "2027-01-15" }.
locals {
  minimum_versions = [
    { package = "InnerSource.Telemetry", minimum = "1.0.1", deadline = "2026-11-17" },
  ]
}

# Every pipeline may read the group, since it holds no secret and every pipeline on the ci
# template reads it
resource "azuredevops_variable_group" "minimum_versions" {
  project_id   = data.azuredevops_project.groundwerk.id
  name         = "minimum-versions"
  description  = "The minimum versions of packages that builds must reach, set in infra/azdo/minimum-versions.tf (CICD-17)"
  allow_access = true

  variable {
    name  = "minimumVersions"
    value = jsonencode(local.minimum_versions)
  }
}
