# ---------------------------------------------------------------------------
# Identity and access for the hub-and-spoke environment.
# Principle: assign roles to GROUPS, put PEOPLE in groups. Access then follows
# the job, and a leaver loses everything by being removed, not by someone
# remembering every place they were granted access.
# ---------------------------------------------------------------------------

data "azurerm_subscription" "current" {}

# Resource groups owned by the network project (read only, not managed here).
data "azurerm_resource_group" "scoped" {
  for_each = var.scope_resource_groups
  name     = each.value
}

locals {
  scopes = merge(
    { subscription = data.azurerm_subscription.current.id },
    { for key, rg in data.azurerm_resource_group.scoped : key => rg.id }
  )

  # One entry per (user, group) pair.
  memberships = {
    for pair in flatten([
      for user_key, user in var.users : [
        for group in user.groups : {
          key   = "${user_key}|${group}"
          user  = user_key
          group = group
        }
      ]
    ]) : pair.key => pair
  }
}

# Initial passwords for lab accounts. They live in state (a private blob) and
# are never printed. Users must change them at first sign-in.
resource "random_password" "user" {
  for_each         = var.users
  length           = 20
  special          = true
  override_special = "!#%&*()-_=+"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azuread_user" "lab" {
  for_each = var.users

  user_principal_name   = "lab.${each.key}@${var.tenant_domain}"
  mail_nickname         = "lab.${each.key}"
  display_name          = each.value.display_name
  job_title             = each.value.job_title
  department            = each.value.department
  employee_type         = each.value.employee_type
  usage_location        = "US"
  account_enabled       = each.value.account_enabled
  password              = random_password.user[each.key].result
  force_password_change = true

  lifecycle {
    ignore_changes = [password] # users change it; do not fight them
  }
}

resource "azuread_group" "access" {
  for_each = var.groups

  display_name            = each.key
  description             = each.value.description
  security_enabled        = true
  prevent_duplicate_names = true
}

resource "azuread_group_member" "membership" {
  for_each = local.memberships

  group_object_id  = azuread_group.access[each.value.group].object_id
  member_object_id = azuread_user.lab[each.value.user].object_id

  lifecycle {
    precondition {
      condition     = contains(keys(var.groups), each.value.group)
      error_message = "User ${each.value.user} references a group that is not defined in var.groups: ${each.value.group}"
    }
  }
}

# One built-in role per group, scoped as narrowly as the job allows.
resource "azurerm_role_assignment" "group" {
  for_each = var.groups

  scope                = local.scopes[each.value.scope]
  role_definition_name = each.value.role
  principal_id         = azuread_group.access[each.key].object_id
  principal_type       = "Group"

  lifecycle {
    precondition {
      condition     = contains(keys(local.scopes), each.value.scope)
      error_message = "Group ${each.key} uses an unknown scope: ${each.value.scope}. Use hub, dev, prod or subscription."
    }
  }
}
