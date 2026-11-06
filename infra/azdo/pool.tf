# The Managed DevOps Pool, for the scheduled and long-running jobs, so they don't use the hosted
# grant's 1,800 minutes. It runs as the organization's free self-hosted parallel job, and Azure
# bills its VM only while a job runs (CICD-15). It joins the private network in phase 3.

# Microsoft requires whoever creates a pool to be a member of each project it serves
data "azuredevops_group" "groundwerk_readers" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "Readers"
}

resource "azuredevops_group_membership" "azdo_reader" {
  group   = data.azuredevops_group.groundwerk_readers.descriptor
  members = [azuredevops_service_principal_entitlement.azdo.descriptor]
  mode    = "add"
}

resource "azurerm_resource_group" "pool" {
  name     = "rg-groundwerk-pool"
  location = "eastus"
}

# A Managed DevOps Pool belongs to a Dev Center project. Neither costs anything on its own.
resource "azurerm_dev_center" "pool" {
  name                = "dc-groundwerk"
  resource_group_name = azurerm_resource_group.pool.name
  location            = azurerm_resource_group.pool.location
}

resource "azurerm_dev_center_project" "pool" {
  name                = "dcp-groundwerk"
  dev_center_id       = azurerm_dev_center.pool.id
  resource_group_name = azurerm_resource_group.pool.name
  location            = azurerm_resource_group.pool.location
}

# One agent at a time, made for each job and removed after it, with none kept on standby
resource "azurerm_managed_devops_pool" "pool" {
  name                  = "groundwerk-pool"
  resource_group_name   = azurerm_resource_group.pool.name
  location              = azurerm_resource_group.pool.location
  dev_center_project_id = azurerm_dev_center_project.pool.id
  maximum_concurrency   = 1

  azure_devops_organization {
    organization {
      url         = "https://dev.azure.com/mikewicks-lab"
      projects    = ["GroundWerk"]
      parallelism = 1
    }

    # Admins of all agent pools also administer this one, so the pipeline can change it later
    permission {
      kind = "Inherit"
    }
  }

  stateless_agent {}

  virtual_machine_scale_set_fabric {
    sku_name = "Standard_D2ads_v5"

    image {
      well_known_image_name = "ubuntu-24.04-g2"
    }
  }

  depends_on = [azuredevops_group_membership.azdo_reader]
}

# The pool's queue in GroundWerk, which Azure DevOps gets when the pool is created. A pipeline
# that runs on the pool needs an azuredevops_pipeline_authorization for it, added in this file.
data "azuredevops_agent_queue" "pool" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = azurerm_managed_devops_pool.pool.name

  # Read after the pool exists, not during the plan that creates it
  depends_on = [azurerm_managed_devops_pool.pool]
}
