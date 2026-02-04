data "github_repository_file" "github_infra_configs" {
  for_each = { for cfg in lookup(var.config_repo_files, "github", []) : cfg.file_path => cfg }

  repository = each.value.repository
  branch     = try(each.value.branch, var.default_config_branch)
  file       = each.value.file_path
}

data "gitlab_repository_file" "gitlab_infra_configs" {
  for_each = { for cfg in lookup(var.config_repo_files, "gitlab", []) : cfg.file_path => cfg }

  project   = each.value.project
  file_path = each.value.file_path
  ref       = try(each.value.ref, var.default_config_branch)
}

data "github_repository_file" "config_defaults" {
  for_each = lookup(var.config_defaults, "service") == "github" ? var.config_defaults : {}

  repository = each.value.repository
  branch     = try(each.value.branch, var.default_config_branch)
  file       = each.value.file_path
}

data "gitlab_repository_file" "config_defaults" {
  for_each = lookup(var.config_defaults, "service") == "gitlab" ? var.config_defaults : {}

  project   = each.value.repository
  ref       = try(each.value.branch, var.default_config_branch)
  file_path = each.value.file_path
}
