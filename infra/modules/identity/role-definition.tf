
resource "azurerm_role_definition" "terraform_ci_role_assignments" {
  name        = "daiberia-fleetops-terraform-ci-role-assignments"
  scope       = var.resource_group_id
  description = "Permite crear/leer/borrar role assignments dentro del RG fleetops, sin el resto de privilegios de User Access Administrator."

  permissions {
    actions = [
      "Microsoft.Authorization/roleAssignments/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete",
    ]
    not_actions = []
  }

  assignable_scopes = [
    var.resource_group_id,
  ]
}

# Nueva asignación con el rol custom — ADITIVA, no reemplaza UAA todavía.
# UAA se retira manualmente fuera de Terraform tras verificar en el pipeline
# que este rol custom es suficiente.
resource "azurerm_role_assignment" "terraform_ci_custom_role" {
  scope              = var.resource_group_id
  role_definition_id = azurerm_role_definition.terraform_ci_role_assignments.role_definition_resource_id
  principal_id       = var.terraform_ci_sp_object_id
}