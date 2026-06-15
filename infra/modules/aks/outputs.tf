# modules/aks/outputs.tf

output "cluster_id" {
  description = "ID del cluster AKS"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Nombre del cluster — usado en az aks get-credentials"
  value       = azurerm_kubernetes_cluster.main.name
}

output "kube_config" {
  description = "Kubeconfig para acceso al cluster — sensible, no loggear"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}
