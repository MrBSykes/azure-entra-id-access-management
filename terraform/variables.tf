variable "subscription_id" {
  description = "Azure subscription. Pass with TF_VAR_subscription_id."
  type        = string
}

variable "tenant_domain" {
  description = "Verified domain of the Entra tenant, used for lab user UPNs (for example contoso.onmicrosoft.com). Pass with TF_VAR_tenant_domain."
  type        = string
}

variable "scope_resource_groups" {
  description = "Resource groups from the network project that access is granted on. Keys are used in the groups map."
  type        = map(string)
  default = {
    hub  = "hub-rg"
    dev  = "dev-rg"
    prod = "prod-rg"
  }
}

variable "groups" {
  description = "Security groups, each mapped to ONE built-in role at ONE scope (hub, dev, prod, or subscription)."
  type = map(object({
    description = string
    role        = string
    scope       = string
  }))
}

variable "users" {
  description = "Lab users. Joiner = add an entry. Mover = change groups. Leaver = set account_enabled false, then remove the entry."
  type = map(object({
    display_name    = string
    job_title       = string
    department      = string
    employee_type   = optional(string, "Employee")
    groups          = list(string)
    account_enabled = optional(bool, true)
  }))
}
