# modules/networking/variables.tf

variable "prefix" {
  description = "Prefijo para nombrar todos los recursos del módulo"
  type        = string
}

variable "location" {
  description = "Región Azure donde se despliegan los recursos"
  type        = string
}

variable "resource_group_name" {
  description = "Nombre del resource group donde se crean los recursos"
  type        = string
}

variable "tags" {
  description = "Tags comunes aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
