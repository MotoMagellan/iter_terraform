# S3 Bucket Definition
#
# Configuration-driven S3 bucket creation using the terraform-aws-modules/s3-bucket module
#
# Structure:
#   s3:
#     buckets:
#       bucket-name:
#         bucket: "my-bucket-name"  # Optional - defaults to key name
#         force_destroy: true
#         versioning:
#           enabled: true
#         ... additional bucket configuration options
#

locals {
  s3_defaults = lookup(local.defaults, "s3", {})         # default S3 values for any bucket created
  s3_config   = lookup(local.infra_configs, "s3", {})    # does not create buckets simply by defaults

  # Extract bucket configurations from s3 config
  s3_buckets = lookup(local.s3_config, "buckets", {})
}

################################################################################
# S3 Bucket Module
################################################################################

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 5.0"

  for_each = local.s3_buckets

  # Basic bucket configuration
  create_bucket = try(each.value.create_bucket, true)
  bucket        = try(each.value.bucket, each.key)
  bucket_prefix = try(each.value.bucket_prefix, null)
  region        = try(each.value.region, null)
  force_destroy = try(each.value.force_destroy, local.s3_defaults.force_destroy, false)

  # Access Control
  acl = try(each.value.acl, local.s3_defaults.acl, null)

  # Public Access Block Configuration
  block_public_acls       = try(each.value.block_public_acls, local.s3_defaults.block_public_acls, true)
  block_public_policy     = try(each.value.block_public_policy, local.s3_defaults.block_public_policy, true)
  ignore_public_acls      = try(each.value.ignore_public_acls, local.s3_defaults.ignore_public_acls, true)
  restrict_public_buckets = try(each.value.restrict_public_buckets, local.s3_defaults.restrict_public_buckets, true)

  # Object Ownership
  control_object_ownership = try(each.value.control_object_ownership, local.s3_defaults.control_object_ownership, true)
  object_ownership         = try(each.value.object_ownership, local.s3_defaults.object_ownership, "BucketOwnerEnforced")

  # Versioning
  versioning = try(each.value.versioning, local.s3_defaults.versioning, {})

  # Server-side Encryption
  server_side_encryption_configuration = try(each.value.server_side_encryption_configuration, local.s3_defaults.server_side_encryption_configuration, {})

  # Lifecycle Rules
  lifecycle_rule = try(each.value.lifecycle_rule, local.s3_defaults.lifecycle_rule, [])

  # Intelligent Tiering
  intelligent_tiering = try(each.value.intelligent_tiering, local.s3_defaults.intelligent_tiering, {})

  # Logging
  logging = try(each.value.logging, local.s3_defaults.logging, {})

  # CORS Configuration
  cors_rule = try(each.value.cors_rule, local.s3_defaults.cors_rule, [])

  # Website Configuration
  website = try(each.value.website, local.s3_defaults.website, {})

  # Replication Configuration
  replication_configuration = try(each.value.replication_configuration, local.s3_defaults.replication_configuration, {})

  # Object Lock Configuration
  object_lock_enabled       = try(each.value.object_lock_enabled, local.s3_defaults.object_lock_enabled, false)
  object_lock_configuration = try(each.value.object_lock_configuration, local.s3_defaults.object_lock_configuration, {})

  # Request Payer Configuration
  request_payer = try(each.value.request_payer, local.s3_defaults.request_payer, "BucketOwner")

  # Bucket Policy Attachments
  attach_policy                            = try(each.value.attach_policy, local.s3_defaults.attach_policy, false)
  policy                                   = try(each.value.policy, local.s3_defaults.policy, null)
  attach_elb_log_delivery_policy           = try(each.value.attach_elb_log_delivery_policy, local.s3_defaults.attach_elb_log_delivery_policy, false)
  attach_lb_log_delivery_policy            = try(each.value.attach_lb_log_delivery_policy, local.s3_defaults.attach_lb_log_delivery_policy, false)
  attach_access_log_delivery_policy        = try(each.value.attach_access_log_delivery_policy, local.s3_defaults.attach_access_log_delivery_policy, false)
  attach_cloudtrail_log_delivery_policy    = try(each.value.attach_cloudtrail_log_delivery_policy, local.s3_defaults.attach_cloudtrail_log_delivery_policy, false)
  attach_deny_insecure_transport_policy    = try(each.value.attach_deny_insecure_transport_policy, local.s3_defaults.attach_deny_insecure_transport_policy, false)
  attach_require_latest_tls_policy         = try(each.value.attach_require_latest_tls_policy, local.s3_defaults.attach_require_latest_tls_policy, false)
  attach_deny_unencrypted_object_uploads   = try(each.value.attach_deny_unencrypted_object_uploads, local.s3_defaults.attach_deny_unencrypted_object_uploads, false)
  attach_deny_incorrect_encryption_headers = try(each.value.attach_deny_incorrect_encryption_headers, local.s3_defaults.attach_deny_incorrect_encryption_headers, false)
  attach_deny_incorrect_kms_key_sse        = try(each.value.attach_deny_incorrect_kms_key_sse, local.s3_defaults.attach_deny_incorrect_kms_key_sse, false)
  attach_waf_log_delivery_policy           = try(each.value.attach_waf_log_delivery_policy, local.s3_defaults.attach_waf_log_delivery_policy, false)
  attach_public_policy                     = try(each.value.attach_public_policy, local.s3_defaults.attach_public_policy, false)
  attach_inventory_destination_policy      = try(each.value.attach_inventory_destination_policy, local.s3_defaults.attach_inventory_destination_policy, false)
  attach_analytics_destination_policy      = try(each.value.attach_analytics_destination_policy, local.s3_defaults.attach_analytics_destination_policy, false)

  # Policy Configuration for Deny Incorrect KMS Key SSE
  allowed_kms_key_arn = try(each.value.allowed_kms_key_arn, local.s3_defaults.allowed_kms_key_arn, null)

  # ELB/ALB Log Delivery Policy Configuration
  elb_service_accounts     = try(each.value.elb_service_accounts, local.s3_defaults.elb_service_accounts, {})
  lb_target_account_ids    = try(each.value.lb_target_account_ids, local.s3_defaults.lb_target_account_ids, [])
  lb_target_prefix         = try(each.value.lb_target_prefix, local.s3_defaults.lb_target_prefix, "")
  access_log_delivery_policy_source_accounts = try(each.value.access_log_delivery_policy_source_accounts, local.s3_defaults.access_log_delivery_policy_source_accounts, [])
  access_log_delivery_policy_source_buckets  = try(each.value.access_log_delivery_policy_source_buckets, local.s3_defaults.access_log_delivery_policy_source_buckets, [])

  # CloudTrail Log Delivery Policy Configuration
  cloudtrail_log_delivery_accounts = try(each.value.cloudtrail_log_delivery_accounts, local.s3_defaults.cloudtrail_log_delivery_accounts, [])

  # WAF Log Delivery Policy Configuration
  waf_log_delivery_account_ids = try(each.value.waf_log_delivery_account_ids, local.s3_defaults.waf_log_delivery_account_ids, [])

  # S3 Analytics Configuration
  analytics_configuration = try(each.value.analytics_configuration, local.s3_defaults.analytics_configuration, [])

  # S3 Inventory Configuration
  inventory_configuration = try(each.value.inventory_configuration, local.s3_defaults.inventory_configuration, {})

  # S3 Metrics Configuration
  metric_configuration = try(each.value.metric_configuration, local.s3_defaults.metric_configuration, [])

  # S3 Bucket Notifications
  event_notification_details = try(each.value.event_notification_details, local.s3_defaults.event_notification_details, {})

  # Acceleration Configuration
  acceleration_status = try(each.value.acceleration_status, local.s3_defaults.acceleration_status, null)

  # Ownership Controls - Grant Configuration
  grant = try(each.value.grant, local.s3_defaults.grant, [])

  # Object Ownership - Expected Bucket Owner
  expected_bucket_owner = try(each.value.expected_bucket_owner, local.s3_defaults.expected_bucket_owner, null)

  # Directory Bucket Configuration (S3 Express One Zone)
  is_directory_bucket                              = try(each.value.is_directory_bucket, local.s3_defaults.is_directory_bucket, false)
  data_redundancy                                  = try(each.value.data_redundancy, local.s3_defaults.data_redundancy, null)
  availability_zone_id                             = try(each.value.availability_zone_id, local.s3_defaults.availability_zone_id, null)
  metadata_inventory_table_configuration_state     = try(each.value.metadata_inventory_table_configuration_state, local.s3_defaults.metadata_inventory_table_configuration_state, null)

  # Tags
  tags = merge(
    lookup(local.s3_defaults, "tags", {}),
    local.tags,
    {
      TFModule = "terraform-aws-modules/s3-bucket/aws"
    },
    lookup(each.value, "tags", {}),
  )

  ################################################################################
  # Preconditions for Mutually-Exclusive Parameters
  ################################################################################

  lifecycle {
    # Ensure bucket and bucket_prefix are not both specified
    precondition {
      condition     = !(can(each.value.bucket) && can(each.value.bucket_prefix))
      error_message = "Cannot specify both 'bucket' and 'bucket_prefix' for S3 bucket '${each.key}'. Choose one or the other."
    }

    # Ensure ACL is not used when object_ownership is set to BucketOwnerEnforced
    precondition {
      condition = !(
        try(each.value.object_ownership, local.s3_defaults.object_ownership, "BucketOwnerEnforced") == "BucketOwnerEnforced" &&
        (can(each.value.acl) || can(local.s3_defaults.acl))
      )
      error_message = "Cannot use 'acl' parameter when 'object_ownership' is set to 'BucketOwnerEnforced' for S3 bucket '${each.key}'. Remove 'acl' or change 'object_ownership'."
    }

    # Ensure grant is not used when object_ownership is set to BucketOwnerEnforced
    precondition {
      condition = !(
        try(each.value.object_ownership, local.s3_defaults.object_ownership, "BucketOwnerEnforced") == "BucketOwnerEnforced" &&
        (can(each.value.grant) && length(try(each.value.grant, [])) > 0) ||
        (can(local.s3_defaults.grant) && length(try(local.s3_defaults.grant, [])) > 0)
      )
      error_message = "Cannot use 'grant' parameter when 'object_ownership' is set to 'BucketOwnerEnforced' for S3 bucket '${each.key}'. Remove 'grant' or change 'object_ownership'."
    }

    # Ensure ACL and grant are not both specified
    precondition {
      condition = !(
        (can(each.value.acl) || can(local.s3_defaults.acl)) &&
        ((can(each.value.grant) && length(try(each.value.grant, [])) > 0) ||
        (can(local.s3_defaults.grant) && length(try(local.s3_defaults.grant, [])) > 0))
      )
      error_message = "Cannot specify both 'acl' and 'grant' for S3 bucket '${each.key}'. Choose one or the other."
    }

    # Ensure object_lock_enabled is true if object_lock_configuration is specified
    precondition {
      condition = !(
        (can(each.value.object_lock_configuration) && length(keys(try(each.value.object_lock_configuration, {}))) > 0 ||
        can(local.s3_defaults.object_lock_configuration) && length(keys(try(local.s3_defaults.object_lock_configuration, {}))) > 0) &&
        !try(each.value.object_lock_enabled, local.s3_defaults.object_lock_enabled, false)
      )
      error_message = "Must set 'object_lock_enabled' to true when 'object_lock_configuration' is specified for S3 bucket '${each.key}'."
    }

    # Ensure directory bucket parameters are only used when is_directory_bucket is true
    precondition {
      condition = !(
        !try(each.value.is_directory_bucket, local.s3_defaults.is_directory_bucket, false) &&
        (can(each.value.data_redundancy) || can(each.value.availability_zone_id) || can(each.value.metadata_inventory_table_configuration_state))
      )
      error_message = "Directory bucket parameters ('data_redundancy', 'availability_zone_id', 'metadata_inventory_table_configuration_state') can only be used when 'is_directory_bucket' is true for S3 bucket '${each.key}'."
    }

    # Ensure required directory bucket parameters are set when is_directory_bucket is true
    precondition {
      condition = !(
        try(each.value.is_directory_bucket, local.s3_defaults.is_directory_bucket, false) &&
        (!can(each.value.availability_zone_id) && !can(local.s3_defaults.availability_zone_id))
      )
      error_message = "Must specify 'availability_zone_id' when 'is_directory_bucket' is true for S3 bucket '${each.key}'."
    }

    # Ensure attach_deny_incorrect_kms_key_sse requires allowed_kms_key_arn
    precondition {
      condition = !(
        try(each.value.attach_deny_incorrect_kms_key_sse, local.s3_defaults.attach_deny_incorrect_kms_key_sse, false) &&
        !can(each.value.allowed_kms_key_arn) && !can(local.s3_defaults.allowed_kms_key_arn)
      )
      error_message = "Must specify 'allowed_kms_key_arn' when 'attach_deny_incorrect_kms_key_sse' is true for S3 bucket '${each.key}'."
    }
  }
}
