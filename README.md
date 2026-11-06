# 🔐 Entra ID Access Management for a Hub-and-Spoke Azure Environment
### Users · Security groups · Least-privilege RBAC · Joiner / mover / leaver

![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft_Entra_ID-RBAC-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Cost](https://img.shields.io/badge/Cost-Free_tier-2ea44f?style=for-the-badge)

Identity and access for the environment built in my [Personal Azure Infrastructure](https://github.com/MrBSykes/personal-azure-infrastructure-terraform-IAC) project: lab users, security groups, and role assignments scoped to the hub, dev and prod resource groups. Companion to my [cost guardrails](https://github.com/MrBSykes/azure-cost-visibility-guardrails) project.

> **Status:** code written; deployment, portal evidence and the lifecycle walkthrough to follow. Sections marked *(to verify)* are not yet proven in my tenant.

---

## 1. The Business Problem

*Fictional scenario, built to practice a real-world problem.*

A non-profit's Azure environment is run by a rotating mix of staff, volunteers and contractors. Access was granted one person at a time, usually with whatever role made the request go away fastest. Nobody could answer "who can change production?", and when a contractor's engagement ended, nobody was sure everything they could reach had been removed.

**The root problem is access that is tied to people instead of jobs.** Per-person grants pile up, cannot be reviewed quickly, and fail silently when someone leaves or changes roles.

**What this project does:** access follows the job. People are members of groups, groups hold the roles, and roles are scoped to the smallest resource group that fits. A joiner, a role change and a leaver are each a small, reviewable change.

---

## 2. Azure and Entra Resources, and Why

| Resource | Why it is here | Problem it solves |
|---|---|---|
| **Security groups** (`sg-*`), 5 | One group per job function and environment | Permissions are reviewed per group, not per person |
| **Lab users**, 5 fictional accounts | A manager, developer, network admin, volunteer and contractor | Realistic roles to demonstrate access decisions |
| **Group memberships** | Link people to groups | A role change is a membership change, not a rewrite of permissions |
| **Role assignments** (Azure RBAC), 5 | Each group gets one built-in role at one scope | Least privilege: nobody holds more than the job needs |
| **Data lookups of `hub-rg`, `dev-rg`, `prod-rg`** | Scope access to the network project's resource groups, read only | Access matches the environment boundaries already built |

### Access model

| Group | Role | Scope | Who it is for |
|---|---|---|---|
| `sg-hub-network-admins` | Network Contributor | `hub-rg` | Network administrator |
| `sg-dev-contributors` | Contributor | `dev-rg` | Developer |
| `sg-dev-readers` | Reader | `dev-rg` | Volunteers, contractors, network admin |
| `sg-prod-readers` | Reader | `prod-rg` | Manager, network admin |
| `sg-cost-viewers` | Cost Management Reader | Subscription | Manager (pairs with the cost project) |

**Nobody has write access to prod.** Production changes are meant to flow through reviewed code, which is the reason for the CI/CD item on my roadmap.

---

## 3. Key Architectural Decisions

| # | Decision | Reasoning | Trade-off |
|---|---|---|---|
| 1 | **Roles go to groups, never to individuals** | Access follows the job, and offboarding removes one membership instead of hunting for grants | Needs discipline: a one-off grant to a person defeats the model |
| 2 | **One role at one scope per group** | A group's name states exactly what it can do and where, which makes reviews quick | More groups than a "one group per team" design |
| 3 | **Scope to resource groups, not the subscription** | A contractor who needs dev should not be able to see prod | Subscription-wide roles are used only where the job requires it (cost viewing) |
| 4 | **No write access to prod for any group** | Production changes should be reviewed, not made by hand | Slower emergency changes. A real organization would add a break-glass process |
| 5 | **Users and groups defined as data** (`lab.auto.tfvars`) | Same pattern as my spokes: joiner, mover and leaver are one-line changes with a readable plan | Terraform manages the lab accounts, so portal edits to them show up as drift |
| 6 | **Disable first, delete later** | Disabling stops sign-in immediately and is reversible; deleting is not | An extra step, and a disabled account still exists until removed |
| 7 | **Initial passwords generated and never printed** | No shared or guessable passwords; users must change at first sign-in | Passwords live in the state file (a private blob), so state access must be restricted |
| 8 | **Built-in roles only** | Well understood and auditable; custom roles are a later step | Less precise than a custom role in some cases |
| 9 | **Free Entra features only** | Keeps the lab at no cost | Conditional Access, dynamic groups, group-based licensing and access reviews need paid tiers and are not demonstrated here |

### Known limitations

- Lab users exist only in my personal tenant. A real organization would use a verified company domain and often sync from on-premises Active Directory.
- No Conditional Access or access reviews (paid features). Those are the natural next layer.
- Passwords are stored in Terraform state. A real deployment would use a secrets store or have users self-register credentials.
- A tenant with Security Defaults on may prompt test users to register MFA at first sign-in *(to verify)*, so I verify access through the portal's "Check access" instead of signing in.

---

## 4. How to Deploy

### Prerequisites

- Terraform 1.3 or newer and the Azure CLI, signed in with `az login`
- The network project deployed (this lab reads `hub-rg`, `dev-rg` and `prod-rg`)
- An account that can create users and groups in the tenant and assign roles on the subscription (for a personal tenant, that is typically the account that created it)

### Steps

```powershell
cd terraform
$env:TF_VAR_subscription_id = az account show --query id -o tsv
# The tenant's domain: the part of your sign-in name after the last @
$env:TF_VAR_tenant_domain = (az ad signed-in-user show --query userPrincipalName -o tsv).Split('@')[-1]

terraform init
terraform plan
terraform apply
```

The plan should add 5 users, 5 passwords (random), 5 groups, 8 group memberships and 5 role assignments, with nothing changed or destroyed.

### Cost

Users, groups and Azure role assignments carry no charge on the free tier as far as I know *(to verify on the pricing page)*. Do not enable paid Entra features from the portal.

### Tear down

```bash
terraform destroy
```

Removes every lab user, group and role assignment this project created and nothing else.

---

## 5. Lifecycle Walkthrough: Joiner, Mover, Leaver

Each step is a change to `lab.auto.tfvars` and a `terraform plan` that shows exactly what will happen, matched by what the portal shows.

| Event | Change | Expected plan | Check in the portal |
|---|---|---|---|
| **Joiner**: a new hire starts | Add a user entry with their groups | 1 user, 1 password and one membership per group to add | Entra ID → Users; group → Members |
| **Mover**: a volunteer becomes a developer | Change `groups` from `sg-dev-readers` to `sg-dev-contributors` | 1 membership to destroy, 1 to add | Resource group → Access control (IAM) → Check access |
| **Leaver, step 1**: contractor engagement ends | Set `account_enabled = false` | 1 user updated in place | User shows as blocked from sign-in |
| **Leaver, step 2**: after the retention period | Remove the user entry | User, password and memberships destroyed | User absent from the Users list |

---

## Repository Layout

```
.
├── README.md
└── terraform/
    ├── providers.tf        # azurerm, azuread, random, remote backend
    ├── variables.tf        # users and groups schemas
    ├── main.tf             # users, groups, memberships, role assignments
    ├── outputs.tf          # group IDs, UPNs, sensitive initial passwords
    └── lab.auto.tfvars     # fictional lab users and groups as data
```

## What I Would Do Differently Next Time

1. Define the groups and roles before creating any resources, so nobody is ever granted access one person at a time.
2. Start from a verified company domain and a break-glass account with strong protection.
3. Add Conditional Access and periodic access reviews once the tenant has the licenses for them.
4. Use custom roles only where a built-in role is too broad, and review them regularly.
5. Keep identity in its own repo and state, as here, so an access change is never bundled with a network change.

## Next Steps

- [ ] Deploy, capture portal evidence, and run the joiner, mover and leaver steps
- [ ] Verify one user's effective access with "Check access" on `prod-rg`
- [ ] Add a custom role for a narrow task
- [ ] Connect pipeline access (CI/CD) to a workload identity instead of a user

---

*Bryan Sykes | Home Lab Portfolio | 2026*
