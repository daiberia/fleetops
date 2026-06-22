# modules/identity/main.tf

resource "azurerm_user_assigned_identity" "fleetops" {
  name                = "${var.prefix}-id"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# AcrPull: pull de imágenes sin credenciales
resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.fleetops.principal_id
}

# Key Vault Secrets User: CSI driver lee secretos
resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.fleetops.principal_id
}

# Managed Identity Operator: requerido para que AKS control plane
# pueda asignar la kubelet identity al node pool
resource "azurerm_role_assignment" "managed_identity_operator" {
  scope                = azurerm_user_assigned_identity.fleetops.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.fleetops.principal_id
}

# Storage Blob Data Contributor acotado al container tfstate:
# permite al SP de Terraform CI leer/escribir el state sin listKeys (bypass RBAC)
resource "azurerm_role_assignment" "terraform_ci_tfstate" {
  scope                = "${var.tfstate_storage_account_id}/blobServices/default/containers/tfstate"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.terraform_ci_sp_object_id
}
