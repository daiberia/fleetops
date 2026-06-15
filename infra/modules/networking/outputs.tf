# modules/networking/outputs.tf

output "vnet_id" {
  description = "ID de la Virtual Network principal"
  value       = azurerm_virtual_network.main.id
}

output "aks_subnet_id" {
  description = "ID de la subnet asignada al cluster AKS"
  value       = azurerm_subnet.aks.id
}

output "services_subnet_id" {
  description = "ID de la subnet de servicios Azure (Key Vault, Storage)"
  value       = azurerm_subnet.services.id
}
