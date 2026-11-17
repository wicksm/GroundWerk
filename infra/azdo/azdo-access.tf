# Azure DevOps seats for the service principals: Basic, which Repos needs (SDLC-10)

data "azuredevops_group" "project_collection_administrators" {
  name = "Project Collection Administrators"
}

resource "azuredevops_service_principal_entitlement" "azdo" {
  origin_id            = azuread_service_principal.azdo.object_id
  account_license_type = "express" # Basic

  lifecycle {
    prevent_destroy = true
  }
}

# Administers Azure DevOps, so it can change repos, policies, service connections and environments
resource "azuredevops_group_membership" "azdo_admin" {
  group   = data.azuredevops_group.project_collection_administrators.descriptor
  members = [azuredevops_service_principal_entitlement.azdo.descriptor]
  mode    = "add" # never "overwrite", which would take you out of the group

  lifecycle {
    prevent_destroy = true
  }
}

# Its permissions in GroundWerk are in ai-developer.tf
resource "azuredevops_service_principal_entitlement" "ai_developer" {
  origin_id            = azuread_service_principal.ai_developer.object_id
  account_license_type = "express" # Basic
}

# Renovate's seat. Its permissions in GroundWerk are in renovate.tf
resource "azuredevops_service_principal_entitlement" "renovate" {
  origin_id            = azuread_service_principal.renovate.object_id
  account_license_type = "express" # Basic
}
