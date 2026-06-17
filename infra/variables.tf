# variables.tf — raíz
# Valores por defecto alineados al naming convention cerrado

variable "prefix" {
  description = "Prefijo global para todos los recursos"
  type        = string
  default     = "daiberia-fleetops"
}

variable "location" {
  description = "Región Azure — fijada a francecentral por Azure for Students"
  type        = string
  default     = "francecentral"
}

variable "acr_name" {
  description = "Nombre del ACR — sin guiones, globalmente único"
  type        = string
  default     = "daiberiafleetopsacr"
}

variable "db_password" {
  description = "Password PostgreSQL — pasar via TF_VAR o -var, nunca en código"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT signing secret — mínimo 32 caracteres"
  type        = string
  sensitive   = true
}

variable "db_url" {
  description = "PostgreSQL connection string completa"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags comunes aplicados a todos los recursos Azure"
  type        = map(string)
  default = {
    project     = "fleetops"
    owner       = "daiberia"
    environment = "prod"
    managed_by  = "terraform"
  }
}



