# outputs.tf — raíz
# Outputs relevantes post-apply para configurar kubectl y pipelines

output "aks_cluster_name" {
  description = "Nombre del cluster — para az aks get-credentials"
  value       = module.aks.cluster_name
}

output "resource_group_name" {
  description = "Resource group principal"
  value       = azurerm_resource_group.main.name
}

output "acr_login_server" {
  description = "URL del registry — para docker push y GitHub Actions"
  value       = module.acr.acr_login_server
}

output "keyvault_uri" {
  description = "URI del Key Vault — para configurar CSI driver"
  value       = module.keyvault.keyvault_uri
}

output "law_workspace_id" {
  description = "Workspace ID del LAW — para queries KQL"
  value       = module.monitoring.law_workspace_id
}
