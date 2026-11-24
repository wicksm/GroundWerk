# The Managed DevOps Pool, for the scheduled and long-running jobs, so they don't use the hosted
# grant's 1,800 minutes. It runs as the organization's free self-hosted parallel job, and Azure
# bills its VM only while a job runs (CICD-15). It joins the private network in phase 3.

# Microsoft requires whoever creates a pool to be a member of each project it serves
data "azuredevops_group" "readers" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = "Readers"
}

resource "azuredevops_group_membership" "azdo_reader" {
  group   = data.azuredevops_group.readers.descriptor
  members = [azuredevops_service_principal_entitlement.azdo.descriptor]
  mode    = "add"
}

resource "azurerm_resource_group" "pool" {
  name     = "rg-${var.workload}-pool"
  location = "eastus"
}

# A Managed DevOps Pool belongs to a Dev Center project. Neither costs anything on its own.
resource "azurerm_dev_center" "pool" {
  name                = "dc-${var.workload}"
  resource_group_name = azurerm_resource_group.pool.name
  location            = azurerm_resource_group.pool.location
}

resource "azurerm_dev_center_project" "pool" {
  name                = "dcp-${var.workload}"
  dev_center_id       = azurerm_dev_center.pool.id
  resource_group_name = azurerm_resource_group.pool.name
  location            = azurerm_resource_group.pool.location
}

# One agent at a time, made for each job and removed after it, with none kept on standby
resource "azurerm_managed_devops_pool" "pool" {
  name                  = "${var.workload}-pool"
  resource_group_name   = azurerm_resource_group.pool.name
  location              = azurerm_resource_group.pool.location
  dev_center_project_id = azurerm_dev_center_project.pool.id
  maximum_concurrency   = 1

  azure_devops_organization {
    organization {
      url         = "https://dev.azure.com/mikewicks-lab"
      projects    = [data.azuredevops_project.groundwerk.name]
      parallelism = 1
    }

    # Inherit turns on inheritance for the project's copy of the pool only. The organization's
    # copy got Project Collection Administrators, which includes groundwerk-azdo, as
    # Administrator by hand on November 5, since the provider can't set it yet
    # (terraform-provider-azuredevops issue 1609). Add that again by hand if the pool is recreated.
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

  # Azure reports the pool differently from how it's written here: it leaves out the admin
  # permission, which is set only when the pool is created, and adds image aliases and empty
  # tags. Without this, every plan would replace the pool.
  lifecycle {
    ignore_changes = [
      azure_devops_organization[0].permission,
      virtual_machine_scale_set_fabric[0].image[0].aliases,
      tags,
    ]
  }
}

# The pool's queue in the project, which Azure DevOps gets when the pool is created. A pipeline
# that runs on the pool needs an azuredevops_pipeline_authorization for it, added in this file.
data "azuredevops_agent_queue" "pool" {
  project_id = data.azuredevops_project.groundwerk.id
  name       = azurerm_managed_devops_pool.pool.name

  # Read after the pool exists, not during the plan that creates it
  depends_on = [azurerm_managed_devops_pool.pool]
}

# Pipeline ai-developer runs on the pool (ADR 0006)
resource "azuredevops_pipeline_authorization" "ai_developer_pool" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "queue"
  resource_id = data.azuredevops_agent_queue.pool.id
  pipeline_id = azuredevops_build_definition.ai_developer.id
}

# Pipeline run-renovate runs on the pool (docs/adr/0010)
resource "azuredevops_pipeline_authorization" "renovate_pool" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "queue"
  resource_id = data.azuredevops_agent_queue.pool.id
  pipeline_id = azuredevops_build_definition.renovate.id
}

# Pipeline mirror-to-github runs on the pool (docs/adr/0013)
resource "azuredevops_pipeline_authorization" "github_mirror_pool" {
  project_id  = data.azuredevops_project.groundwerk.id
  type        = "queue"
  resource_id = data.azuredevops_agent_queue.pool.id
  pipeline_id = azuredevops_build_definition.github_mirror.id
}
