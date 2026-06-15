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

variable "db_password" {
  description = "Password de PostgreSQL — se pasa como variable sensible, nunca hardcodeada"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret para firma de JWT — mínimo 32 caracteres"
  type        = string
  sensitive   = true
}

variable "db_url" {
  description = "Connection string completa de PostgreSQL"
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
