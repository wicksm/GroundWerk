terraform {
  required_version = ">= 1.7"

  # State lives in HCP Terraform, which only holds it; plans and applies run where Terraform runs (IAC-2)
  cloud {
    organization = "mikewicks-lab"
    workspaces {
      name = "azdo"
    }
  }

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

# By hand, these sign in as you: azuredevops with your PAT, and azuread and azurerm with your
# admin account through az login. From the pipeline, all three sign in as groundwerk-azdo
# through azdo-service-connection (IAC-12).
provider "azuredevops" {}

provider "azuread" {}

provider "azurerm" {
  # azurerm registers no resource providers unless told to. The pool needs DevCenter and DevOpsInfrastructure, and the registry and its identities need ContainerRegistry and ManagedIdentity.
  resource_providers_to_register = ["Microsoft.ContainerRegistry", "Microsoft.DevCenter", "Microsoft.DevOpsInfrastructure", "Microsoft.ManagedIdentity"]

  features {}
}
