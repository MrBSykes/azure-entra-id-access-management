# 🔐 Entra ID Access Management for a Hub-and-Spoke Azure Environment
### Users · Security groups · Least-privilege RBAC · Joiner / mover / leaver

![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft_Entra_ID-RBAC-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Cost](https://img.shields.io/badge/Cost-Free_tier-2ea44f?style=for-the-badge)

Identity and access for the environment built in my [Personal Azure Infrastructure](https://github.com/MrBSykes/personal-azure-infrastructure-terraform-IAC) project: lab users, security groups, and role assignments scoped to the hub, dev and prod resource groups. Companion to my [cost guardrails](https://github.com/MrBSykes/azure-cost-visibility-guardrails) project.

> **Status:** deployed and verified in my own tenant. 28 resources applied, the mover and leaver steps run, and least-privilege behavior confirmed by signing in as a lab user. See the [screenshots](#screenshots) and the [troubleshooting log](#troubleshooting-log).

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
| **Group memberships**, 8 | Link people to groups | A role change is a membership change, not a rewrite of permissions |
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
| 5 | **Users and groups defined as data** (`lab.auto.tfvars`) | Same pattern as my spokes: joiner, mover and leaver are small edits with a readable plan | Terraform manages the lab accounts, so portal edits to them show up as drift |
| 6 | **Disable first, delete later** | Disabling stops sign-in immediately and is reversible; deleting removes the account, though Entra keeps it recoverable for 30 days | An extra step, and a disabled account keeps its group memberships until removed |
| 7 | **Initial passwords generated and never printed** | No shared or guessable passwords; users must change at first sign-in | Passwords live in the state file (a private blob), so state access must be restricted |
| 8 | **Built-in roles only** | Well understood and auditable; custom roles are a later step | Less precise than a custom role in some cases |
| 9 | **Free Entra features only** | Keeps the lab at no cost | Conditional Access, dynamic groups, group-based licensing and access reviews need paid tiers and are not demonstrated here |
| 10 | **Lifecycle steps wrapped in a script** (`scripts/lifecycle.ps1`) | Each step edits the data file, shows the plan and waits for an explicit `y` before applying, so a mistyped answer cannot apply a change | Regex edits to the data file are brittle if its layout changes. Fine for a lab, but a real team would use a proper request workflow |

### Known limitations

- Lab users exist only in my personal tenant. A real organization would use a verified company domain and often sync from on-premises Active Directory.
- No Conditional Access or access reviews (paid features). Those are the natural next layer.
- Passwords are stored in Terraform state. A real deployment would use a secrets store or have users self-register credentials.
- Security Defaults is on in my tenant, so each lab user is forced to register an authenticator app at first sign-in and cannot skip it. I left it on on purpose.
- The leaver walkthrough has no "sign-in blocked" screenshot for the disabled contractor: I did the disable and delete steps before testing a sign-in as that user. The plan output and the Deleted users page are the evidence instead.

### Control alignment (concepts only)

This is a personal commercial subscription, **not** a FedRAMP or NIST 800-53 compliant environment, and I make no compliance claim. The lab practices the ideas behind a few access-control families:

| Concept | How the lab practices it |
|---|---|
| **AC-2 Account management** | Accounts are created, changed, disabled and removed through a reviewable change, with the full lifecycle shown |
| **AC-6 Least privilege** | One role at the smallest scope that fits, with no write access to prod |
| **Role-based access** | Permissions attach to groups that represent jobs, not to individuals |

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

The first plan adds 28 resources: 5 users, 5 passwords (random), 5 groups, 8 group memberships and 5 role assignments, with nothing changed or destroyed. A second `terraform plan` should then report no changes.

To read a lab user's initial password (for testing only, and never commit or screenshot it):

```powershell
terraform output -json lab_initial_passwords
```

### Cost

Users, groups and Azure role assignments carry no charge on the free tier as far as I know *(to verify on the pricing page)*. Do not enable paid Entra features from the portal.

### Tear down

```bash
terraform destroy
```

Removes every lab user, group and role assignment this project created and nothing else.

---

## 5. Lifecycle Walkthrough: Joiner, Mover, Leaver

Each step is a change to `lab.auto.tfvars` and a `terraform plan` that shows exactly what will happen, matched by what the portal shows. The script runs each step: `.\scripts\lifecycle.ps1 -Step mover | disable | remove`.

| Event | Change | Plan result | Check in the portal |
|---|---|---|---|
| **Joiner**: five lab users start | The initial `apply` | 28 added (above) | Entra ID → Users, screenshot 01 |
| **Mover**: a volunteer becomes a developer | Victor's `groups` changed from `sg-dev-readers` to `sg-dev-contributors` | 1 to add, 0 to change, 1 to destroy | Group → Members |
| **Leaver, step 1**: contractor engagement ends | Connor set to `account_enabled = false` | 0 to add, 1 to change, 0 to destroy (`account_enabled` true → false) | Users |
| **Leaver, step 2**: after the retention period | Connor's entry removed from the users map | Account removed | Users shows 5 (screenshot 05); **Deleted users** lists him, recoverable until the 30-day mark (screenshot 06) |

A plain `terraform plan` after each step reported no changes, so the code and the tenant agreed throughout. The final committed `lab.auto.tfvars` is the end state: Victor in `sg-dev-contributors` and Connor removed.

### Least-privilege checks

I signed in as the developer (Devon Carter, `sg-dev-contributors`, Contributor on `dev-rg`) in a private browser window, so my admin session stayed separate:

- He sees only `dev-rg` in the resource group list (07).
- He is denied when creating a resource group under the subscription (08).
- He reaches the Review + create step for a storage account inside `dev-rg` (09). I did not click Create.
- From my admin session, Check access on `prod-rg` shows 0 role assignments and 0 deny assignments for him (10).

---

## Screenshots

| # | File | What it shows |
|---|---|---|
| 01 | `01-entra-users-list.png` | The five lab users plus my admin account |
| 02 | `02-group-members-sg-dev-readers.png` | A security group with its members |
| 03 | `03-dev-rg-role-assignments.png` | Group-based roles on `dev-rg` |
| 04 | `04-prod-rg-role-assignments-no-write.png` | `prod-rg` has only Reader and the inherited cost role |
| 05 | `05-users-after-leaver-connor-removed.png` | Five users after the leaver step |
| 06 | `06-deleted-users-connor-recoverable.png` | The removed user is recoverable for 30 days |
| 07 | `07-devon-sees-only-dev-rg.png` | The developer sees only `dev-rg` |
| 08 | `08-devon-denied-create-permission.png` | The developer cannot create resource groups |
| 09 | `09-devon-can-create-in-dev-rg.png` | The developer can build inside `dev-rg` |
| 10 | `10-devon-check-access-prod-rg-zero.png` | Check access: no assignments on `prod-rg` |

Tenant domain, subscription ID and my own account details are redacted in every screenshot.

---

## Troubleshooting Log

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | My first plan summary said 23 resources | I miscounted: it is 5 users + 5 passwords + 5 groups + 8 memberships + 5 role assignments = 28 | Counted from the code, and the real plan said 28 |
| 2 | `running scripts is disabled on this system` | PowerShell's default execution policy blocks local scripts | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` for that window only |
| 3 | `git diff` printed its usage text inside the script | The project was not a git repository yet | `git init`, then commit before the next lifecycle step |
| 4 | Typing `yes` at the apply prompt did nothing | The script only accepts a lowercase `y` by design | Applied the saved plan file directly with `terraform apply "remove.tfplan"` |
| 5 | A lab user could not skip MFA registration | Security Defaults requires an authenticator app at first sign-in | Registered a test authenticator entry, then removed it afterwards |
| 6 | "The resource ID is invalid" in my first prod test | I pasted a URL with a literal `<id>` placeholder, which is not a permissions error | Dropped that screenshot and proved the prod boundary with Check access instead |

---

## Repository Layout

```
.
├── README.md
├── screenshots/            # redacted portal evidence (01-10)
├── scripts/
│   └── lifecycle.ps1       # mover / disable / remove with plan-then-confirm
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
6. Test the sign-in for each lifecycle state before moving to the next one. I ran disable and delete in quick succession and missed the "account disabled" evidence.

## Next Steps

- [ ] Add a custom role for a narrow task
- [ ] Connect pipeline access (CI/CD) to a workload identity instead of a user
- [ ] Add a drift demo: change a group membership in the portal and show the plan catching it

---

*Bryan Sykes | Home Lab Portfolio | 2026*
