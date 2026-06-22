terraform {
  backend "azurerm" {
    resource_group_name  = "daiberia-tfstate-rg"
    storage_account_name = "daiberiatfstate"
    container_name       = "tfstate"
    key                  = "fleetops/terraform.tfstate"
    use_azuread_auth     = true
  }
}