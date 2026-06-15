# modules/monitoring/main.tf
# Log Analytics Workspace — base obligatoria para Sentinel y OMS Agent de AKS

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name

  # PerGB2018 — pago por GB ingestado, más económico para Students
  sku               = "PerGB2018"
  retention_in_days = 30  # Mínimo para Sentinel, suficiente para demo

  tags = var.tags
}

# Solución ContainerInsights — habilita métricas de nodos y pods en LAW
resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}
