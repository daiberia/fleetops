# modules/aks/variables.tf

variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "aks_subnet_id" {
  description = "Subnet dedicada para los nodos AKS"
  type        = string
}

variable "identity_id" {
  description = "ID completo de la Managed Identity asignada al cluster"
  type        = string
}

variable "identity_client_id" {
  description = "Client ID de la Managed Identity — requerido por kubelet_identity"
  type        = string
}

variable "identity_principal_id" {
  description = "Principal ID de la Managed Identity — requerido por kubelet_identity"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID del LAW — OMS agent envía logs aquí para Sentinel"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
