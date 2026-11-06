# Where pipelines deploy, each with its gates (CICD-5, CICD-20, CICD-23). Nothing deploys until
# phase 3, or to qa, st and pr until phase 5. The required template check waits for the deploy
# template in phase 5 (CICD-22).

locals {
  environments = {
    azdo = "Pipeline azdo-terraform's apply waits here for your approval (IAC-12)"
    ci   = "Built each time you start work and torn down after (COST-3)"
    dv   = "Brought up on demand for dev testing (IAC-10)"
    qa   = "Merged code for the teams testing against it, from phase 5 (CICD-23)"
    st   = "Only what's about to ship, from phase 5 (CICD-5)"
    pr   = "Production, deployed only after 8pm Eastern, from phase 5 (CICD-20)"
  }
}

resource "azuredevops_environment" "env" {
  for_each    = local.environments
  project_id  = data.azuredevops_project.groundwerk.id
  name        = each.key
  description = each.value
}

# You're the only real person, so you approve your own runs, while your second user approves PRs
data "azuredevops_group" "project_administrators" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "Project Administrators"
}

resource "azuredevops_check_approval" "env" {
  for_each             = toset(["azdo", "st", "pr"])
  project_id           = data.azuredevops_project.groundwerk.id
  target_resource_id   = azuredevops_environment.env[each.key].id
  target_resource_type = "environment"

  approvers             = [data.azuredevops_group.project_administrators.origin_id]
  requester_can_approve = true
  instructions          = "Check what this run will change before you approve it."
}

resource "azuredevops_check_branch_control" "env" {
  for_each                 = toset(["qa", "st", "pr"])
  project_id               = data.azuredevops_project.groundwerk.id
  display_name             = "Only main"
  target_resource_id       = azuredevops_environment.env[each.key].id
  target_resource_type     = "environment"
  allowed_branches         = "refs/heads/main"
  verify_branch_protection = true
}

resource "azuredevops_check_business_hours" "pr" {
  project_id           = data.azuredevops_project.groundwerk.id
  display_name         = "After 8pm Eastern"
  target_resource_id   = azuredevops_environment.env["pr"].id
  target_resource_type = "environment"
  start_time           = "20:00"
  end_time             = "23:59"
  time_zone            = "Eastern Standard Time"
  monday               = true
  tuesday              = true
  wednesday            = true
  thursday             = true
  friday               = true
  saturday             = true
  sunday               = true
}