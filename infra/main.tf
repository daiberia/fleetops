# main.tf — raíz
# Orquesta todos los módulos respetando el orden de dependencias:
# networking → identity → acr → aks → keyvault → monitoring → sentinel

locals {
  prefix   = var.prefix
  location = var.location
  tags     = var.tags
}

# Resource group principal — contenedor de toda la infra FleetOps
resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = local.location
  tags     = local.tags
}

# 1. Networking — VNet, subnets, NSGs
module "networking" {
  source = "./modules/networking"

  prefix              = local.prefix
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# 2. ACR — debe existir antes que identity (identity necesita acr_id para RBAC)
module "acr" {
  source = "./modules/acr"

  acr_name            = var.acr_name
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# 3. Monitoring — LAW debe existir antes que AKS (oms_agent necesita law_id)
#    y antes que Sentinel
module "monitoring" {
  source = "./modules/monitoring"

  prefix              = local.prefix
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# 4. Key Vault — debe existir antes que identity (identity necesita keyvault_id para RBAC)
module "keyvault" {
  source = "./modules/keyvault"

  prefix                = local.prefix
  location              = local.location
  resource_group_name   = azurerm_resource_group.main.name
  services_subnet_id    = module.networking.services_subnet_id
  aks_subnet_id         = module.networking.aks_subnet_id
  allowed_ips           = var.allowed_ips
  identity_principal_id = module.identity.identity_principal_id
  tags                  = local.tags
}

# 5. Identity — Managed Identity + RBAC sobre ACR y Key Vault
module "identity" {
  source = "./modules/identity"

  prefix                    = local.prefix
  location                  = local.location
  resource_group_name       = azurerm_resource_group.main.name
  acr_id                    = module.acr.acr_id
  keyvault_id               = module.keyvault.keyvault_id
  tags                      = local.tags # 
  resource_group_id         = azurerm_resource_group.main.id
  terraform_ci_sp_object_id = "e2812c9d-cde5-4be9-b9d0-d71b86548b64"
}

# F3 verificado: SP sin UAA, mínimo privilegio confirmado
# 6. AKS — depende de networking, identity y monitoring
module "aks" {
  source = "./modules/aks"

  prefix                     = local.prefix
  location                   = local.location
  resource_group_name        = azurerm_resource_group.main.name
  aks_subnet_id              = module.networking.aks_subnet_id
  identity_id                = module.identity.identity_id
  identity_client_id         = module.identity.identity_client_id
  identity_principal_id      = module.identity.identity_principal_id
  log_analytics_workspace_id = module.monitoring.law_id
  tags                       = local.tags
}

# 7. Sentinel — depende de monitoring (necesita law_id)
module "sentinel" {
  source = "./modules/sentinel"

  law_id = module.monitoring.law_id
}
