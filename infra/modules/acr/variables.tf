# modules/acr/variables.tf

variable "acr_name" {
  description = "Nombre del ACR — sin guiones, globalmente único en Azure"
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
