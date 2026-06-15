# modules/keyvault/outputs.tf

output "keyvault_id" {
  description = "ID del Key Vault — usado en RBAC assignments del módulo identity"
  value       = azurerm_key_vault.main.id
}

output "keyvault_uri" {
  description = "URI del Key Vault — usado en la configuración del CSI driver"
  value       = azurerm_key_vault.main.vault_uri
}
