# modules/acr/main.tf
# Azure Container Registry privado — imágenes FleetOps

resource "azurerm_container_registry" "main" {
  # ACR no admite guiones en el nombre — limitación de Azure
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic" # Suficiente para Students, ~0.15$/día

  # Admin credentials desactivadas — acceso solo via Managed Identity
  admin_enabled = false

  tags = var.tags
}
