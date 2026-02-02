# This local declaration is for managing of default values and global
# locals used by multiple module
locals {
  infra_configs = merge(concat(
    [for ds in values(data.github_repository_file.github_infra_configs) : yamldecode(ds.content)],
    [for ds in values(data.gitlab_repository_file.gitlab_infra_configs) : yamldecode(ds.content)]
  )...)

  defaults = lookup(local.infra_configs, "defaults", {})

  tags = merge({
    TFParentModule = "iter_terraform"
    },
    var.tags
  )

  # Map of KMS key 'purpose' tag values to key ARNs for tag-based lookups
  # Used by resources (e.g., DynamoDB) that reference KMS keys via the custom-key pattern
  kms_keys_by_purpose = {
    for k, v in local.kms_keys :
    try(lookup(lookup(v, "tags", {}), "purpose", null), lookup(lookup(v, "tags", {}), "Purpose", null)) => module.kms[k].key_arn
    if try(lookup(lookup(v, "tags", {}), "purpose", null), lookup(lookup(v, "tags", {}), "Purpose", null)) != null
  }
}
