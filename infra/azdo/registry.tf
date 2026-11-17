# The container registry for the image that .devcontainer builds, which every pipeline's container
# job runs in (CICD-18, ARC-9, docs/adr/0007). Basic, the smallest tier, at about $5 a month.
# Pipeline build-image pushes the image, and pipelines pull it by its digest (docs/adr/0008).

resource "azurerm_resource_group" "registry" {
  name     = "rg-groundwerk-registry"
  location = "eastus"
}

# No admin user and no anonymous pull, the defaults, so every sign-in goes through Entra ID. Public
# network access stays on, since private endpoints and network rules need Premium, and the registry
# has no identity of its own, since it runs no tasks and customer-managed keys need Premium too.
resource "azurerm_container_registry" "registry" {
  name                = "crgroundwerk"
  resource_group_name = azurerm_resource_group.registry.name
  location            = azurerm_resource_group.registry.location
  sku                 = "Basic"
}

# Pipelines reach the registry through two service connections with no stored secret, each signing
# in as a managed identity of its own. A managed identity can't be given a secret at all, so each
# signs in only through its connection.

# registry-pull may only pull. PR builds use it, so it has no Only main check (docs/adr/0008).
resource "azurerm_user_assigned_identity" "registry_pull" {
  name                = "id-groundwerk-registry-pull"
  resource_group_name = azurerm_resource_group.registry.name
  location            = azurerm_resource_group.registry.location
}

resource "azurerm_role_assignment" "registry_pull" {
  scope                = azurerm_container_registry.registry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.registry_pull.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azuredevops_serviceendpoint_azurecr" "registry_pull" {
  project_id                             = data.azuredevops_project.groundwerk.id
  service_endpoint_name                  = "registry-pull"
  description                            = "Pulls images from crgroundwerk"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  resource_group                         = azurerm_resource_group.registry.name
  azurecr_name                           = azurerm_container_registry.registry.name
  azurecr_spn_tenantid                   = data.azurerm_subscription.current.tenant_id
  azurecr_subscription_id                = data.azurerm_subscription.current.subscription_id
  azurecr_subscription_name              = data.azurerm_subscription.current.display_name

  credentials {
    serviceprincipalid = azurerm_user_assigned_identity.registry_pull.client_id
  }
}

resource "azurerm_federated_identity_credential" "registry_pull" {
  name                      = "registry-pull"
  user_assigned_identity_id = azurerm_user_assigned_identity.registry_pull.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azuredevops_serviceendpoint_azurecr.registry_pull.workload_identity_federation_issuer
  subject                   = azuredevops_serviceendpoint_azurecr.registry_pull.workload_identity_federation_subject
}

# registry-push may pull and push. Only pipeline build-image may use it, and only from main.
resource "azurerm_user_assigned_identity" "registry_push" {
  name                = "id-groundwerk-registry-push"
  resource_group_name = azurerm_resource_group.registry.name
  location            = azurerm_resource_group.registry.location
}

resource "azurerm_role_assignment" "registry_push" {
  scope                = azurerm_container_registry.registry.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.registry_push.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azuredevops_serviceendpoint_azurecr" "registry_push" {
  project_id                             = data.azuredevops_project.groundwerk.id
  service_endpoint_name                  = "registry-push"
  description                            = "Pushes images to crgroundwerk"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  resource_group                         = azurerm_resource_group.registry.name
  azurecr_name                           = azurerm_container_registry.registry.name
  azurecr_spn_tenantid                   = data.azurerm_subscription.current.tenant_id
  azurecr_subscription_id                = data.azurerm_subscription.current.subscription_id
  azurecr_subscription_name              = data.azurerm_subscription.current.display_name

  credentials {
    serviceprincipalid = azurerm_user_assigned_identity.registry_push.client_id
  }
}

resource "azurerm_federated_identity_credential" "registry_push" {
  name                      = "registry-push"
  user_assigned_identity_id = azurerm_user_assigned_identity.registry_push.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azuredevops_serviceendpoint_azurecr.registry_push.workload_identity_federation_issuer
  subject                   = azuredevops_serviceendpoint_azurecr.registry_push.workload_identity_federation_subject
}

resource "azuredevops_check_branch_control" "registry_push" {
  project_id               = data.azuredevops_project.groundwerk.id
  display_name             = "Only main"
  target_resource_id       = azuredevops_serviceendpoint_azurecr.registry_push.id
  target_resource_type     = "endpoint"
  allowed_branches         = "refs/heads/main"
  verify_branch_protection = true
}

# Pipeline build-image builds the image and pushes it, on each change to it on main
resource "azuredevops_build_definition" "build_image" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "build-image"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk"].id
    branch_name = "refs/heads/main"
    yml_path    = "pipelines/build-image.yml"
  }

  ci_trigger {
    use_yaml = true
  }
}

resource "azuredevops_pipeline_authorization" "build_image_registry" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "endpoint"
  resource_id = azuredevops_serviceendpoint_azurecr.registry_push.id
  pipeline_id = azuredevops_build_definition.build_image.id
}
