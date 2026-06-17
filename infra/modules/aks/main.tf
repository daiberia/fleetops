# modules/aks/main.tf
# Cluster AKS — 1 nodo Standard_D2as_v4 (2vCPU / 8GB) — Azure for Students
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.prefix}-aks"

  kubernetes_version  = "1.35.4"
  oidc_issuer_enabled = true # requerido por CSI Secrets Store driver

  default_node_pool {
    name                = "system"
    node_count          = 1
    vm_size             = "Standard_D2as_v4" # 2vCPU / 8GB — único disponible en Students
    vnet_subnet_id      = var.aks_subnet_id
    os_disk_size_gb     = 64
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = false
    max_pods            = 110 # requiere network_plugin_mode = overlay

    upgrade_settings {
      # max_surge="1" es requerido por la API de AKS (no acepta "0" sin max_unavailable,
      # que solo existe en azurerm v4). RIESGO CONOCIDO: un upgrade K8s con quota agotada
      # fallará al intentar crear el nodo surge. Verificar quota antes de cualquier upgrade.
      max_surge = "1"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  kubelet_identity {
    client_id                 = var.identity_client_id
    object_id                 = var.identity_principal_id
    user_assigned_identity_id = var.identity_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"        # pods usan CIDR propio — no consume IPs de VNet por pod
    pod_cidr            = "192.168.0.0/16" # no solapa: VNet=10.0.0.0/16, service=172.16.0.0/16
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  tags = var.tags
}