# Fictional lab data: no real people, no secrets. Safe to commit.

groups = {
  "sg-hub-network-admins" = {
    description = "Manage hub networking only"
    role        = "Network Contributor"
    scope       = "hub"
  }
  "sg-dev-contributors" = {
    description = "Build and change resources in dev"
    role        = "Contributor"
    scope       = "dev"
  }
  "sg-dev-readers" = {
    description = "Look, but do not change, in dev"
    role        = "Reader"
    scope       = "dev"
  }
  "sg-prod-readers" = {
    description = "Read-only access to production. Nobody gets write access here"
    role        = "Reader"
    scope       = "prod"
  }
  "sg-cost-viewers" = {
    description = "See spend across the subscription (pairs with the cost guardrails project)"
    role        = "Cost Management Reader"
    scope       = "subscription"
  }
}

users = {
  "ava.mitchell" = {
    display_name = "Ava Mitchell (lab)"
    job_title    = "Program Manager"
    department   = "Programs"
    groups       = ["sg-cost-viewers", "sg-prod-readers"]
  }
  "devon.carter" = {
    display_name = "Devon Carter (lab)"
    job_title    = "Developer"
    department   = "Technology"
    groups       = ["sg-dev-contributors"]
  }
  "nina.patel" = {
    display_name = "Nina Patel (lab)"
    job_title    = "Network Administrator"
    department   = "Technology"
    groups       = ["sg-hub-network-admins", "sg-dev-readers", "sg-prod-readers"]
  }
  "victor.ramos" = {
    display_name  = "Victor Ramos (lab)"
    job_title     = "Volunteer"
    department    = "Programs"
    employee_type = "Volunteer"
    groups        = ["sg-dev-contributors"]
  }
}
