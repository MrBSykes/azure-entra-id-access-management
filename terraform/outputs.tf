output "group_object_ids" {
  value = { for name, g in azuread_group.access : name => g.object_id }
}

output "lab_user_principal_names" {
  value = { for key, u in azuread_user.lab : key => u.user_principal_name }
}

# Only needed if you want to sign in as a lab user. Read with:
#   terraform output -json lab_initial_passwords
output "lab_initial_passwords" {
  value     = { for key, p in random_password.user : key => p.result }
  sensitive = true
}
