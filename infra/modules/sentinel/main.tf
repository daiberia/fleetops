# modules/sentinel/main.tf
# KQL rules usando tablas disponibles desde el primer día en LAW
# ApiRequests y KubeAuditAdminLogs se activan cuando AKS envía datos (post-deploy app)

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id = var.law_id
}

# Regla 1 — Brute force: tabla AzureDiagnostics disponible desde el primer día
resource "azurerm_sentinel_alert_rule_scheduled" "brute_force_api" {
  name                       = "fleetops-brute-force-api"
  log_analytics_workspace_id = var.law_id
  display_name               = "FleetOps - Posible Brute Force en API"
  severity                   = "Medium"
  enabled                    = true

  query = <<-KQL
    SigninLogs
    | where ResultType != "0"
    | summarize FailedAttempts = count() by IPAddress, bin(TimeGenerated, 5m)
    | where FailedAttempts > 20
  KQL

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping { enabled = false }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# Regla 2 — Escalada privilegios: KQL corregido sin format_datetime
resource "azurerm_sentinel_alert_rule_scheduled" "privilege_escalation" {
  name                       = "fleetops-privilege-escalation"
  log_analytics_workspace_id = var.law_id
  display_name               = "FleetOps - Escalada de Privilegios Entra ID"
  severity                   = "High"
  enabled                    = true

  query = <<-KQL
    AuditLogs
    | where OperationName == "Add member to role"
    | where TargetResources has "Global Administrator"
    | extend HourOfDay = toint(format_timespan(TimeGenerated - startofday(TimeGenerated), 'h'))
    | where HourOfDay < 9 or HourOfDay >= 18
  KQL

  query_frequency   = "PT15M"
  query_period      = "PT15M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping { enabled = false }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# Regla 3 — kubectl exec: tabla ContainerLog disponible cuando AKS conecta a LAW
resource "azurerm_sentinel_alert_rule_scheduled" "kubectl_exec_prod" {
  name                       = "fleetops-kubectl-exec-prod"
  log_analytics_workspace_id = var.law_id
  display_name               = "FleetOps - kubectl exec en Namespace Producción"
  severity                   = "High"
  enabled                    = true

  query = <<-KQL
    AzureActivity
    | where OperationNameValue has "Microsoft.ContainerService"
    | where ActivityStatusValue == "Success"
    | where Properties has "exec"
    | where ResourceGroup has "fleetops"
  KQL

  query_frequency   = "PT5M"
  query_period      = "PT5M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping { enabled = false }
  }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}
