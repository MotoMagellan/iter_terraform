# KMS Key Definition
#
# Configuration-driven KMS key creation using the terraform-aws-modules/kms module
#
# Structure:
#   kms:
#     key-name:
#       description: "My KMS key for encrypting resources"
#       key_usage: "ENCRYPT_DECRYPT"  # Optional - defaults to ENCRYPT_DECRYPT
#       customer_master_key_spec: "SYMMETRIC_DEFAULT"  # Optional
#       deletion_window_in_days: 30  # Optional - defaults to 30
#       enable_key_rotation: true  # Optional - defaults to true
#       multi_region: false  # Optional - defaults to false
#       aliases: ["alias/my-key", "alias/my-other-key"]  # Optional - list of aliases
#       resource_policy:  # Optional - KMS key policy statements
#         AllowRootAccess:
#           sid: "Enable IAM User Permissions"
#           effect: "Allow"
#           principals:
#             - type: "AWS"
#               identifiers: ["arn:aws:iam::123456789012:root"]
#           actions: ["kms:*"]
#           resources: ["*"]
#         AllowDynamoDBAccess:
#           sid: "Allow DynamoDB to use the key"
#           effect: "Allow"
#           principals:
#             - type: "Service"
#               identifiers: ["dynamodb.amazonaws.com"]
#           actions:
#             - "kms:Decrypt"
#             - "kms:DescribeKey"
#             - "kms:CreateGrant"
#           resources: ["*"]
#           conditions:
#             - test: "StringEquals"
#               variable: "kms:ViaService"
#               values: ["dynamodb.us-east-1.amazonaws.com"]
#       ... additional KMS key configuration options
#

locals {
  kms_defaults = lookup(local.defaults, "kms", {})      # default KMS values for any key created
  kms_config   = lookup(local.infra_configs, "kms", {}) # does not create keys simply by defaults

  # Extract KMS key configurations from kms config
  kms_keys = local.kms_config
}

################################################################################
# KMS Key Module
################################################################################

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 4.0"

  for_each = local.kms_keys

  # Basic key configuration
  create      = try(each.value.create, true)
  description = try(each.value.description, local.kms_defaults.description, "KMS key ${each.key}")

  # Key specifications
  key_usage                = try(each.value.key_usage, local.kms_defaults.key_usage, "ENCRYPT_DECRYPT")
  customer_master_key_spec = try(each.value.customer_master_key_spec, local.kms_defaults.customer_master_key_spec, "SYMMETRIC_DEFAULT")
  key_spec                 = try(each.value.key_spec, local.kms_defaults.key_spec, null)

  # Multi-region key
  multi_region = try(each.value.multi_region, local.kms_defaults.multi_region, false)

  # Deletion and rotation
  deletion_window_in_days = try(each.value.deletion_window_in_days, local.kms_defaults.deletion_window_in_days, 30)
  enable_key_rotation     = try(each.value.enable_key_rotation, local.kms_defaults.enable_key_rotation, true)
  rotation_period_in_days = try(each.value.rotation_period_in_days, local.kms_defaults.rotation_period_in_days, null)

  # Key state
  is_enabled = try(each.value.is_enabled, local.kms_defaults.is_enabled, true)

  # Bypass policy lockout safety check
  bypass_policy_lockout_safety_check = try(each.value.bypass_policy_lockout_safety_check, local.kms_defaults.bypass_policy_lockout_safety_check, false)

  # Custom key store
  custom_key_store_id = try(each.value.custom_key_store_id, local.kms_defaults.custom_key_store_id, null)

  # Policy Configuration
  # If resource_policy is provided, construct policy; otherwise use default policy
  enable_default_policy             = !can(each.value.resource_policy)
  key_owners                        = try(each.value.key_owners, local.kms_defaults.key_owners, [])
  key_administrators                = try(each.value.key_administrators, local.kms_defaults.key_administrators, [])
  key_users                         = try(each.value.key_users, local.kms_defaults.key_users, [])
  key_service_users                 = try(each.value.key_service_users, local.kms_defaults.key_service_users, [])
  key_service_roles_for_autoscaling = try(each.value.key_service_roles_for_autoscaling, local.kms_defaults.key_service_roles_for_autoscaling, [])

  # If custom resource_policy is provided, use it
  key_statements            = can(each.value.resource_policy) ? [for k, v in each.value.resource_policy : v] : []
  source_policy_documents   = try(each.value.source_policy_documents, local.kms_defaults.source_policy_documents, [])
  override_policy_documents = try(each.value.override_policy_documents, local.kms_defaults.override_policy_documents, [])
  enable_route53_dnssec     = try(each.value.enable_route53_dnssec, local.kms_defaults.enable_route53_dnssec, false)

  # Aliases
  aliases                 = try(each.value.aliases, local.kms_defaults.aliases, [])
  computed_aliases        = try(each.value.computed_aliases, local.kms_defaults.computed_aliases, {})
  aliases_use_name_prefix = try(each.value.aliases_use_name_prefix, local.kms_defaults.aliases_use_name_prefix, false)

  # Grants
  grants = try(each.value.grants, local.kms_defaults.grants, {})

  # Tags
  tags = merge(
    lookup(local.kms_defaults, "tags", {}),
    local.tags,
    {
      TFModule = "terraform-aws-modules/kms/aws"
    },
    lookup(each.value, "tags", {}),
  )
}

################################################################################
# Validation Resources
################################################################################
# Since lifecycle preconditions are not supported in module blocks, we create
# terraform_data resources to validate configuration parameters before deployment

resource "terraform_data" "kms_validation" {
  for_each = local.kms_keys

  lifecycle {
    # Ensure deletion_window_in_days is valid (7-30)
    precondition {
      condition = (
        try(each.value.deletion_window_in_days, local.kms_defaults.deletion_window_in_days, 30) >= 7 &&
        try(each.value.deletion_window_in_days, local.kms_defaults.deletion_window_in_days, 30) <= 30
      )
      error_message = "The 'deletion_window_in_days' for KMS key '${each.key}' must be between 7-30 days. Current value: ${try(each.value.deletion_window_in_days, local.kms_defaults.deletion_window_in_days, 30)}."
    }

    # Ensure enable_key_rotation is only true for symmetric encryption keys
    precondition {
      condition = !(
        try(each.value.enable_key_rotation, local.kms_defaults.enable_key_rotation, true) &&
        try(each.value.key_usage, local.kms_defaults.key_usage, "ENCRYPT_DECRYPT") != "ENCRYPT_DECRYPT"
      )
      error_message = "Key rotation can only be enabled for symmetric encryption keys (key_usage = ENCRYPT_DECRYPT) for KMS key '${each.key}'. Current key_usage: ${try(each.value.key_usage, local.kms_defaults.key_usage, "ENCRYPT_DECRYPT")}."
    }

    # Ensure enable_key_rotation is only true for symmetric keys
    precondition {
      condition = !(
        try(each.value.enable_key_rotation, local.kms_defaults.enable_key_rotation, true) &&
        try(each.value.customer_master_key_spec, local.kms_defaults.customer_master_key_spec, "SYMMETRIC_DEFAULT") != "SYMMETRIC_DEFAULT"
      )
      error_message = "Key rotation can only be enabled for symmetric keys (customer_master_key_spec = SYMMETRIC_DEFAULT) for KMS key '${each.key}'. Current customer_master_key_spec: ${try(each.value.customer_master_key_spec, local.kms_defaults.customer_master_key_spec, "SYMMETRIC_DEFAULT")}."
    }

    # Ensure rotation_period_in_days is only used when enable_key_rotation is true
    precondition {
      condition = !(
        !try(each.value.enable_key_rotation, local.kms_defaults.enable_key_rotation, true) &&
        (can(each.value.rotation_period_in_days) || can(local.kms_defaults.rotation_period_in_days))
      )
      error_message = "Cannot specify 'rotation_period_in_days' when 'enable_key_rotation' is false for KMS key '${each.key}'. Set 'enable_key_rotation' to true or remove 'rotation_period_in_days'."
    }

    # Ensure rotation_period_in_days is valid (90-2560)
    precondition {
      condition = (
        !can(each.value.rotation_period_in_days) && !can(local.kms_defaults.rotation_period_in_days) ||
        (
          try(each.value.rotation_period_in_days, local.kms_defaults.rotation_period_in_days, 365) >= 90 &&
          try(each.value.rotation_period_in_days, local.kms_defaults.rotation_period_in_days, 365) <= 2560
        )
      )
      error_message = "The 'rotation_period_in_days' for KMS key '${each.key}' must be between 90-2560 days when specified. Current value: ${try(each.value.rotation_period_in_days, local.kms_defaults.rotation_period_in_days, "not set")}."
    }

    # Ensure custom_key_store_id is only used with SYMMETRIC_DEFAULT
    precondition {
      condition = !(
        (can(each.value.custom_key_store_id) || can(local.kms_defaults.custom_key_store_id)) &&
        try(each.value.customer_master_key_spec, local.kms_defaults.customer_master_key_spec, "SYMMETRIC_DEFAULT") != "SYMMETRIC_DEFAULT"
      )
      error_message = "Custom key stores can only be used with symmetric keys (customer_master_key_spec = SYMMETRIC_DEFAULT) for KMS key '${each.key}'."
    }

    # Ensure multi_region is not used with custom_key_store_id
    precondition {
      condition = !(
        try(each.value.multi_region, local.kms_defaults.multi_region, false) &&
        (can(each.value.custom_key_store_id) || can(local.kms_defaults.custom_key_store_id))
      )
      error_message = "Cannot use 'multi_region' with 'custom_key_store_id' for KMS key '${each.key}'. Multi-region keys cannot be created in a custom key store."
    }

    # Validate that aliases is a list if provided
    precondition {
      condition = (
        !can(each.value.aliases) && !can(local.kms_defaults.aliases) ||
        can(tolist(try(each.value.aliases, local.kms_defaults.aliases, [])))
      )
      error_message = "The 'aliases' parameter must be a list of strings for KMS key '${each.key}'."
    }
  }
}
