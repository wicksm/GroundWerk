# The identities the pipelines and the AI developer sign in as (IAC-12). an admin creates them
# once by hand, and from then on the azdo pipeline manages them. The deploy pipelines'
# identities come in phase 3, when something first deploys.

data "azuread_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}

locals {
  # Owner, Role Based Access Control Administrator and User Access Administrator
  admin_role_ids = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635, f58310d9-a9f6-439a-9e8d-f62e7b41a168, 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9"
}

# The azdo pipeline's identity, the most powerful in the project, so its apply waits for your approval.
# It has no owners, so only an admin can change this registration or its federated credential.
resource "azuread_application_registration" "azdo" {
  display_name = "groundwerk-azdo"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azuread_service_principal" "azdo" {
  client_id = azuread_application_registration.azdo.client_id

  lifecycle {
    prevent_destroy = true
  }
}

# No secret: the pipeline proves who it is with a short-lived token from the azdo service connection
resource "azuread_application_federated_identity_credential" "azdo" {
  application_id = azuread_application_registration.azdo.id
  display_name   = "azdo-service-connection"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = azuredevops_serviceendpoint_azurerm.azdo.workload_identity_federation_issuer
  subject        = azuredevops_serviceendpoint_azurerm.azdo.workload_identity_federation_subject

  lifecycle {
    prevent_destroy = true
  }
}

# Creates app registrations and manages the ones it owns, and reads the rest. Only an admin
# can change these grants, since the pipeline can't grant itself permissions.
resource "azuread_app_role_assignment" "azdo_graph" {
  for_each            = toset(["Application.Read.All", "Application.ReadWrite.OwnedBy"])
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.key]
  principal_object_id = azuread_service_principal.azdo.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Builds what later stories need, starting with the Managed DevOps Pool
resource "azurerm_role_assignment" "azdo_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.azdo.object_id
  principal_type       = "ServicePrincipal"
}

# Gives the deploy identities their roles, but never Owner or a role that hands out roles, using
# Microsoft's "Allow all except specific roles" condition
resource "azurerm_role_assignment" "azdo_role_assigner" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.azdo.object_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {${local.admin_role_ids}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {${local.admin_role_ids}}))"
}

# The AI developer's identity, with no way to sign in until the AI-5 spike decides how
resource "azuread_application_registration" "ai_developer" {
  display_name = "groundwerk-ai-developer"
}

resource "azuread_service_principal" "ai_developer" {
  client_id = azuread_application_registration.ai_developer.client_id
  owners    = [azuread_service_principal.azdo.object_id]
}

resource "azuread_application_owner" "ai_developer" {
  application_id  = azuread_application_registration.ai_developer.id
  owner_object_id = azuread_service_principal.azdo.object_id
}