# Secrets Manager Definition
#
# Configuration-driven AWS Secrets Manager secret creation using the terraform-aws-modules/secrets-manager module
#
# Structure:
#   secrets:
#     secrets:
#       secret-name:
#         name: "my-secret-name"  # Optional - defaults to key name
#         description: "My secret description"
#         secret_string: "my-secret-value"
#         kms_key_id: "arn:aws:kms:..."
#         enable_rotation: true
#         rotation_lambda_arn: "arn:aws:lambda:..."
#         secret_resource_policy:  # Optional - map of IAM policy statements
#           AllowReadAccess:
#             sid: "AllowReadAccess"
#             effect: "Allow"
#             principals:
#               - type: "AWS"
#                 identifiers: ["arn:aws:iam::123456789012:role/MyRole"]
#             actions: ["secretsmanager:GetSecretValue"]
#           DenyExternalAccess:
#             sid: "DenyExternalAccess"
#             effect: "Deny"
#             principals:
#               - type: "*"
#                 identifiers: ["*"]
#             actions: ["secretsmanager:*"]
#             conditions:
#               - test: "StringNotEquals"
#                 variable: "aws:PrincipalOrgID"
#                 values: ["o-xxxxxxxxxx"]
#         ... additional secret configuration options
#

locals {
  secrets_defaults = lookup(local.defaults, "secrets", {})      # default Secrets Manager values for any secret created
  secrets_config   = lookup(local.infra_configs, "secrets", {}) # does not create secrets simply by defaults

  # Extract secret configurations from secrets config
  secrets = lookup(local.secrets_config, "secrets", {})
}

################################################################################
# Secrets Manager Module
################################################################################

module "secrets_manager" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "~> 2.0"

  for_each = local.secrets

  # Basic secret configuration
  create      = try(each.value.create, true)
  name        = try(each.value.name, each.key)
  name_prefix = try(each.value.name_prefix, local.secrets_defaults.name_prefix, null)
  description = try(each.value.description, local.secrets_defaults.description, null)
  region      = try(each.value.region, local.secrets_defaults.region, null)

  # Encryption Configuration
  kms_key_id = try(each.value.kms_key_id, local.secrets_defaults.kms_key_id, null)

  # Deletion Configuration
  recovery_window_in_days = try(each.value.recovery_window_in_days, local.secrets_defaults.recovery_window_in_days, 30)

  # Replication Configuration
  replica                        = try(each.value.replica, local.secrets_defaults.replica, {})
  force_overwrite_replica_secret = try(each.value.force_overwrite_replica_secret, local.secrets_defaults.force_overwrite_replica_secret, false)

  # Policy Configuration
  # If secret_resource_policy is provided, use it; otherwise policy is not created
  create_policy             = can(each.value.secret_resource_policy) ? true : false
  block_public_policy       = try(each.value.block_public_policy, local.secrets_defaults.block_public_policy, true)
  policy_statements         = can(each.value.secret_resource_policy) ? each.value.secret_resource_policy : {}
  source_policy_documents   = try(each.value.source_policy_documents, local.secrets_defaults.source_policy_documents, [])
  override_policy_documents = try(each.value.override_policy_documents, local.secrets_defaults.override_policy_documents, [])

  # Secret Value Configuration
  ignore_secret_changes    = try(each.value.ignore_secret_changes, local.secrets_defaults.ignore_secret_changes, false)
  secret_string            = try(each.value.secret_string, local.secrets_defaults.secret_string, null)
  secret_binary            = try(each.value.secret_binary, local.secrets_defaults.secret_binary, null)
  secret_string_wo         = try(each.value.secret_string_wo, local.secrets_defaults.secret_string_wo, null)
  secret_string_wo_version = try(each.value.secret_string_wo_version, local.secrets_defaults.secret_string_wo_version, null)
  version_stages           = try(each.value.version_stages, local.secrets_defaults.version_stages, null)

  # Random Password Generation
  create_random_password           = try(each.value.create_random_password, local.secrets_defaults.create_random_password, false)
  random_password_length           = try(each.value.random_password_length, local.secrets_defaults.random_password_length, 32)
  random_password_override_special = try(each.value.random_password_override_special, local.secrets_defaults.random_password_override_special, null)

  # Rotation Configuration
  enable_rotation     = try(each.value.enable_rotation, local.secrets_defaults.enable_rotation, false)
  rotate_immediately  = try(each.value.rotate_immediately, local.secrets_defaults.rotate_immediately, null)
  rotation_lambda_arn = try(each.value.rotation_lambda_arn, local.secrets_defaults.rotation_lambda_arn, null)
  rotation_rules      = try(each.value.rotation_rules, local.secrets_defaults.rotation_rules, {})

  # Tags
  tags = merge(
    lookup(local.secrets_defaults, "tags", {}),
    local.tags,
    {
      TFModule = "terraform-aws-modules/secrets-manager/aws"
    },
    lookup(each.value, "tags", {}),
  )
}

################################################################################
# Validation Resources
################################################################################
# Since lifecycle preconditions are not supported in module blocks, we create
# terraform_data resources to validate configuration parameters before deployment

resource "terraform_data" "secrets_validation" {
  for_each = local.secrets

  lifecycle {
    # Ensure name and name_prefix are not both specified
    precondition {
      condition     = !(can(each.value.name) && can(each.value.name_prefix))
      error_message = "Cannot specify both 'name' and 'name_prefix' for secret '${each.key}'. Choose one or the other."
    }

    # Ensure only one secret value type is specified
    precondition {
      condition = (
        (can(each.value.secret_string) ? 1 : 0) +
        (can(each.value.secret_binary) ? 1 : 0) +
        (can(each.value.secret_string_wo) ? 1 : 0) +
        (can(each.value.create_random_password) && each.value.create_random_password ? 1 : 0)
      ) <= 1
      error_message = "Cannot specify more than one of 'secret_string', 'secret_binary', 'secret_string_wo', or 'create_random_password' for secret '${each.key}'. Choose only one method to provide the secret value."
    }

    # Ensure recovery_window_in_days is valid (0 or 7-30)
    precondition {
      condition = (
        try(each.value.recovery_window_in_days, local.secrets_defaults.recovery_window_in_days, 30) == 0 ||
        (try(each.value.recovery_window_in_days, local.secrets_defaults.recovery_window_in_days, 30) >= 7 &&
        try(each.value.recovery_window_in_days, local.secrets_defaults.recovery_window_in_days, 30) <= 30)
      )
      error_message = "The 'recovery_window_in_days' for secret '${each.key}' must be 0 (force delete) or between 7-30 days. Current value: ${try(each.value.recovery_window_in_days, local.secrets_defaults.recovery_window_in_days, 30)}."
    }

    # Ensure rotation_lambda_arn is specified when enable_rotation is true
    precondition {
      condition = !(
        try(each.value.enable_rotation, local.secrets_defaults.enable_rotation, false) &&
        !can(each.value.rotation_lambda_arn) && !can(local.secrets_defaults.rotation_lambda_arn)
      )
      error_message = "Must specify 'rotation_lambda_arn' when 'enable_rotation' is true for secret '${each.key}'."
    }

    # Ensure rotation_rules is only used when enable_rotation is true
    precondition {
      condition = !(
        !try(each.value.enable_rotation, local.secrets_defaults.enable_rotation, false) &&
        (
          (can(each.value.rotation_rules) && length(keys(try(each.value.rotation_rules, {}))) > 0) ||
          (can(local.secrets_defaults.rotation_rules) && length(keys(try(local.secrets_defaults.rotation_rules, {}))) > 0)
        )
      )
      error_message = "Cannot specify 'rotation_rules' when 'enable_rotation' is false for secret '${each.key}'. Set 'enable_rotation' to true or remove 'rotation_rules'."
    }

    # Ensure rotate_immediately is only used when enable_rotation is true
    precondition {
      condition = !(
        !try(each.value.enable_rotation, local.secrets_defaults.enable_rotation, false) &&
        (can(each.value.rotate_immediately) || can(local.secrets_defaults.rotate_immediately))
      )
      error_message = "Cannot specify 'rotate_immediately' when 'enable_rotation' is false for secret '${each.key}'. Set 'enable_rotation' to true or remove 'rotate_immediately'."
    }

    # Ensure secret_string_wo_version is only used with secret_string_wo
    precondition {
      condition = !(
        (can(each.value.secret_string_wo_version) || can(local.secrets_defaults.secret_string_wo_version)) &&
        !can(each.value.secret_string_wo) && !can(local.secrets_defaults.secret_string_wo)
      )
      error_message = "Cannot specify 'secret_string_wo_version' without 'secret_string_wo' for secret '${each.key}'."
    }

    # Ensure random_password_* parameters are only used with create_random_password
    precondition {
      condition = !(
        !try(each.value.create_random_password, local.secrets_defaults.create_random_password, false) &&
        (
          can(each.value.random_password_length) ||
          can(each.value.random_password_override_special)
        )
      )
      error_message = "Cannot specify 'random_password_length' or 'random_password_override_special' when 'create_random_password' is false for secret '${each.key}'. Set 'create_random_password' to true or remove these parameters."
    }

    # Ensure replica configuration is valid (each replica must have region)
    precondition {
      condition = alltrue([
        for k, v in try(each.value.replica, local.secrets_defaults.replica, {}) :
        can(v.region)
      ])
      error_message = "Each replica configuration for secret '${each.key}' must specify a 'region'."
    }
  }
}
