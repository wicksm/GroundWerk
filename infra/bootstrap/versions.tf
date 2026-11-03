terraform {
  required_version = ">= 1.7"

  # State lives in HCP Terraform, which only holds it; plans and applies run where Terraform runs (IAC-2)
  cloud {
    organization = "mikewicks-lab"
    workspaces {
      name = "azdo-bootstrap"
    }
  }

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.0"
    }
  }
}

# Signs in with AZDO_ORG_SERVICE_URL and AZDO_PERSONAL_ACCESS_TOKEN, as an admin until a pipeline takes over (IAC-12)
provider "azuredevops" {}