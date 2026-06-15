# modules/keyvault/main.tf

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "${var.prefix}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Durante desarrollo: acceso abierto para que Terraform pueda crear secretos
  # En producción real se restringe a subnet + IPs corporativas
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
}

resource "azurerm_key_vault_access_policy" "aks_identity" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.identity_principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "fleetops-db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "fleetops-jwt-secret"
  value        = var.jwt_secret
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}

resource "azurerm_key_vault_secret" "db_url" {
  name         = "fleetops-db-url"
  value        = var.db_url
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_key_vault_access_policy.terraform]
}
