# modules/keyvault/variables.tf

variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "services_subnet_id" {
  description = "Subnet con service endpoint Microsoft.KeyVault — restringe acceso de red"
  type        = string
}

variable "identity_principal_id" {
  description = "Principal ID de la Managed Identity del cluster AKS"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "allowed_ips" {
  description = "IPs publicas autorizadas para acceder al plano de datos del Key Vault (tu IP de desarrollo)"
  type        = list(string)
}

variable "aks_subnet_id" {
  description = "ID de la subnet de AKS, para permitir el acceso del CSI driver al Key Vault"
  type        = string
}