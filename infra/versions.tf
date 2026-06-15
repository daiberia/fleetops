terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # No purgar Key Vault al hacer destroy (evita problemas en Students)
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}
