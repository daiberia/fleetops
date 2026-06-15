# modules/aks/main.tf
# Cluster AKS — 1 nodo Standard_D2as_v4 (2vCPU / 8GB) — Azure for Students

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.prefix}-aks"

  # Kubernetes version — LTS estable, soportada en Students
  kubernetes_version = "1.35.4"

  default_node_pool {
    name                = "system"
    node_count          = 1
    vm_size             = "Standard_D2as_v4"  # 2vCPU / 8GB — único disponible en Students
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = 64
    type                = "VirtualMachineScaleSets"

    # Auto-scaling desactivado — quota Students no lo permite con 1 nodo
    enable_auto_scaling = false
  }

  # Managed Identity asignada por nosotros — zero credenciales hardcodeadas
  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  # Integración nativa con ACR via Managed Identity — sin imagePullSecrets
  kubelet_identity {
    client_id                 = var.identity_client_id
    object_id                 = var.identity_principal_id
    user_assigned_identity_id = var.identity_id
  }

  # Red — Azure CNI para integración con VNet propia
  network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
    service_cidr       = "172.16.0.0/16"   # Fuera del espacio 10.0.0.0/16 de la VNet
    dns_service_ip     = "172.16.0.10"     # Dentro del service_cidr
  }

  # OMS Agent — envía logs y métricas a Log Analytics Workspace para Sentinel
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # RBAC con Entra ID — acceso al cluster via az aks get-credentials
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  tags = var.tags
}
