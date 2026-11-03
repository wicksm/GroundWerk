# The azdo pipeline: it plans every change to infra/azdo on main as groundwerk-azdo,
# and applies it after your approval (IAC-12)

resource "azuredevops_serviceendpoint_azurerm" "azdo" {
  project_id                             = data.azuredevops_project.groundwerk.id
  service_endpoint_name                  = "azdo"
  description                            = "Signs the azdo pipeline in as groundwerk-azdo (IAC-12)"
  service_endpoint_authentication_scheme = "WorkloadIdentityFederation"
  azurerm_spn_tenantid                   = data.azuread_client_config.current.tenant_id
  azurerm_subscription_id                = data.azurerm_subscription.current.subscription_id
  azurerm_subscription_name              = data.azurerm_subscription.current.display_name

  credentials {
    serviceprincipalid = azuread_application_registration.azdo.client_id
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Only a run from main may use the connection, so a branch can't borrow its power
resource "azuredevops_check_branch_control" "azdo_connection" {
  project_id               = data.azuredevops_project.groundwerk.id
  display_name             = "Only main"
  target_resource_id       = azuredevops_serviceendpoint_azurerm.azdo.id
  target_resource_type     = "endpoint"
  allowed_branches         = "refs/heads/main"
  verify_branch_protection = true
}

# The IDs the pipeline signs in with, none of them secret. The HCP token is a secret variable you
# add to the pipeline by hand, so it never reaches Terraform's state.
resource "azuredevops_variable_group" "azdo" {
  project_id   = data.azuredevops_project.groundwerk.id
  name         = "azdo"
  description  = "Sign-in IDs for the azdo pipeline (IAC-12)"
  allow_access = false

  variable {
    name  = "ARM_CLIENT_ID"
    value = azuread_application_registration.azdo.client_id
  }

  variable {
    name  = "ARM_TENANT_ID"
    value = data.azuread_client_config.current.tenant_id
  }

  variable {
    name  = "ARM_SUBSCRIPTION_ID"
    value = data.azurerm_subscription.current.subscription_id
  }

  variable {
    name  = "ARM_ADO_PIPELINE_SERVICE_CONNECTION_ID"
    value = azuredevops_serviceendpoint_azurerm.azdo.id
  }
}

resource "azuredevops_build_definition" "azdo" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "azdo"

  repository {
    repo_type   = "TfsGit"
    repo_id     = azuredevops_git_repository.repo["GroundWerk"].id
    branch_name = "refs/heads/main"
    yml_path    = "infra/azdo/azure-pipelines.yml"
  }

  ci_trigger {
    use_yaml = true
  }

  lifecycle {
    # The HCP token is a variable you add by hand
    ignore_changes = [variable]
  }
}

# Only this pipeline may use the connection, the variable group and the azdo environment
resource "azuredevops_pipeline_authorization" "azdo" {
  for_each = {
    endpoint      = azuredevops_serviceendpoint_azurerm.azdo.id
    variablegroup = azuredevops_variable_group.azdo.id
    environment   = azuredevops_environment.env["azdo"].id
  }

  project_id  = data.azuredevops_project.groundwerk.id
  type        = each.key
  resource_id = each.value
  pipeline_id = azuredevops_build_definition.azdo.id
}