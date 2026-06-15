# modules/identity/variables.tf

variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "acr_id" {
  description = "ID del Azure Container Registry para asignar AcrPull"
  type        = string
}

variable "keyvault_id" {
  description = "ID del Key Vault para asignar Key Vault Secrets User"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
