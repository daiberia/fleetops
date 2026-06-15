# modules/monitoring/outputs.tf

output "law_id" {
  description = "ID del Log Analytics Workspace — requerido por AKS oms_agent y Sentinel"
  value       = azurerm_log_analytics_workspace.main.id
}

output "law_workspace_id" {
  description = "Workspace ID (GUID) — usado en queries KQL y configuración Sentinel"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}
