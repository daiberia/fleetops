# modules/identity/outputs.tf

output "identity_id" {
  description = "ID del recurso Managed Identity"
  value       = azurerm_user_assigned_identity.fleetops.id
}

output "identity_client_id" {
  description = "Client ID de la Managed Identity (usado en AKS y CSI driver)"
  value       = azurerm_user_assigned_identity.fleetops.client_id
}

output "identity_principal_id" {
  description = "Principal ID (Object ID) para asignaciones RBAC adicionales"
  value       = azurerm_user_assigned_identity.fleetops.principal_id
}
