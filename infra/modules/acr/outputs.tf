# modules/acr/outputs.tf

output "acr_id" {
  description = "ID del Container Registry — necesario para RBAC en identity module"
  value       = azurerm_container_registry.main.id
}

output "acr_login_server" {
  description = "URL del registry (ej: daiberiafleetopsacr.azurecr.io)"
  value       = azurerm_container_registry.main.login_server
}
