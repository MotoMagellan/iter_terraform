# DynamoDB Table Definition
#
# Configuration-driven DynamoDB table creation using the terraform-aws-modules/dynamodb-table module
#
# Structure:
#   dynamodb-tables:
#     table-name:
#       name: "my-custom-table-name"  # Optional - defaults to key name
#       create_table: true  # Required - controls whether the table is created
#       config:
#         hash_key: "user_id"
#         range_key: "sort_key"  # Optional
#         attributes:
#           - name: "user_id"
#             type: "S"
#           - name: "sort_key"
#             type: "S"
#         billing_mode: "PAY_PER_REQUEST"  # Optional - defaults to PAY_PER_REQUEST
#         point_in_time_recovery_enabled: true  # Optional - defaults to false
#         ttl_enabled: true  # Optional
#         ttl_attribute_name: "expires_at"  # Optional
#         server_side_encryption_enabled: true  # Optional
#         custom-key: true  # Optional - triggers KMS key lookup by 'purpose' tag matching table key name
#         table_class: "STANDARD"  # Optional
#         deletion_protection_enabled: false  # Optional
#         stream_enabled: true  # Optional
#         stream_view_type: "NEW_AND_OLD_IMAGES"  # Required when stream_enabled is true
#         resource_policy: "{...}"  # Optional - JSON string or map for DynamoDB resource policy
#         contributor_insights:  # Optional - enables CloudWatch Contributor Insights
#           enabled: true
#           index_name: "gsi-name"  # Optional - for GSI-level insights
#         table_export:  # Optional - exports table data to S3
#           s3_bucket: "my-export-bucket"
#           s3_prefix: "dynamodb-exports/"
#           export_format: "DYNAMODB_JSON"  # Optional - DYNAMODB_JSON or ION
#         ... additional DynamoDB table configuration options
#

locals {
  dynamodb_defaults = lookup(local.defaults, "dynamodb-tables", {})      # default DynamoDB values for any table created
  dynamodb_config   = lookup(local.infra_configs, "dynamodb-tables", {}) # does not create tables simply by defaults

  # Extract DynamoDB table configurations from dynamodb-tables config
  dynamodb_tables = local.dynamodb_config
}

################################################################################
# DynamoDB Table Module
################################################################################

module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 5.0"

  for_each = local.dynamodb_tables

  # First-class keys - NOT under config
  name         = try(each.value.name, each.key)
  create_table = try(each.value.create_table, true)

  # Key schema
  hash_key  = try(each.value.config.hash_key, local.dynamodb_defaults.hash_key, null)
  range_key = try(each.value.config.range_key, local.dynamodb_defaults.range_key, null)

  # Attribute definitions
  attributes = try(each.value.config.attributes, local.dynamodb_defaults.attributes, [])

  # Capacity configuration
  billing_mode   = try(each.value.config.billing_mode, local.dynamodb_defaults.billing_mode, "PAY_PER_REQUEST")
  read_capacity  = try(each.value.config.read_capacity, local.dynamodb_defaults.read_capacity, null)
  write_capacity = try(each.value.config.write_capacity, local.dynamodb_defaults.write_capacity, null)

  # Point-in-time recovery
  point_in_time_recovery_enabled        = try(each.value.config.point_in_time_recovery_enabled, local.dynamodb_defaults.point_in_time_recovery_enabled, false)
  point_in_time_recovery_period_in_days = try(each.value.config.point_in_time_recovery_period_in_days, local.dynamodb_defaults.point_in_time_recovery_period_in_days, null)

  # TTL configuration
  ttl_enabled        = try(each.value.config.ttl_enabled, local.dynamodb_defaults.ttl_enabled, false)
  ttl_attribute_name = try(each.value.config.ttl_attribute_name, local.dynamodb_defaults.ttl_attribute_name, "")

  # Secondary indexes
  global_secondary_indexes = try(each.value.config.global_secondary_indexes, local.dynamodb_defaults.global_secondary_indexes, [])
  local_secondary_indexes  = try(each.value.config.local_secondary_indexes, local.dynamodb_defaults.local_secondary_indexes, [])

  # Global table replication
  replica_regions = try(each.value.config.replica_regions, local.dynamodb_defaults.replica_regions, [])

  # DynamoDB Streams
  stream_enabled   = try(each.value.config.stream_enabled, local.dynamodb_defaults.stream_enabled, false)
  stream_view_type = try(each.value.config.stream_view_type, local.dynamodb_defaults.stream_view_type, null)

  # Server-side encryption
  # When custom-key is true, automatically enable SSE and look up KMS key by 'purpose' tag
  server_side_encryption_enabled = try(each.value.config["custom-key"], false) ? true : try(
    each.value.config.server_side_encryption_enabled,
    local.dynamodb_defaults.server_side_encryption_enabled,
    false
  )
  server_side_encryption_kms_key_arn = try(each.value.config["custom-key"], false) ? lookup(
    local.kms_keys_by_purpose, each.key, null
    ) : try(
    each.value.config.server_side_encryption_kms_key_arn,
    local.dynamodb_defaults.server_side_encryption_kms_key_arn,
    null
  )

  # Table class
  table_class = try(each.value.config.table_class, local.dynamodb_defaults.table_class, null)

  # Deletion protection
  deletion_protection_enabled = try(each.value.config.deletion_protection_enabled, local.dynamodb_defaults.deletion_protection_enabled, null)

  # Autoscaling
  autoscaling_enabled  = try(each.value.config.autoscaling_enabled, local.dynamodb_defaults.autoscaling_enabled, false)
  autoscaling_defaults = try(each.value.config.autoscaling_defaults, local.dynamodb_defaults.autoscaling_defaults, {})
  autoscaling_read     = try(each.value.config.autoscaling_read, local.dynamodb_defaults.autoscaling_read, {})
  autoscaling_write    = try(each.value.config.autoscaling_write, local.dynamodb_defaults.autoscaling_write, {})
  autoscaling_indexes  = try(each.value.config.autoscaling_indexes, local.dynamodb_defaults.autoscaling_indexes, {})

  # Import table configuration
  import_table = try(each.value.config.import_table, local.dynamodb_defaults.import_table, {})

  # Ignore changes to GSI (useful for autoscaled tables)
  ignore_changes_global_secondary_index = try(each.value.config.ignore_changes_global_secondary_index, local.dynamodb_defaults.ignore_changes_global_secondary_index, false)

  # On-demand throughput
  on_demand_throughput = try(each.value.config.on_demand_throughput, local.dynamodb_defaults.on_demand_throughput, {})

  # Warm throughput
  warm_throughput = try(each.value.config.warm_throughput, local.dynamodb_defaults.warm_throughput, {})

  # Timeouts
  timeouts = try(each.value.config.timeouts, local.dynamodb_defaults.timeouts, {})

  # Resource policy
  # Accept either a JSON string or a map (which will be jsonencoded)
  resource_policy = can(each.value.config.resource_policy) ? try(
    tostring(each.value.config.resource_policy),
    jsonencode(each.value.config.resource_policy)
  ) : try(tostring(local.dynamodb_defaults.resource_policy), null)

  # Tags
  tags = merge(
    lookup(local.dynamodb_defaults, "tags", {}),
    local.tags,
    {
      TFModule = "terraform-aws-modules/dynamodb-table/aws"
    },
    try(lookup(each.value.config, "tags", {}), {}),
  )
}

################################################################################
# DynamoDB Contributor Insights
################################################################################
# Enables CloudWatch Contributor Insights for DynamoDB tables
# Only created when contributor_insights.enabled is true in the table config

resource "aws_dynamodb_contributor_insights" "this" {
  for_each = {
    for k, v in local.dynamodb_tables : k => v
    if try(v.config.contributor_insights.enabled, false)
  }

  table_name = module.dynamodb_table[each.key].dynamodb_table_id
  index_name = try(each.value.config.contributor_insights.index_name, null)
}

################################################################################
# DynamoDB Table Export to S3
################################################################################
# Exports DynamoDB table data to an S3 bucket
# Requires point-in-time recovery to be enabled on the table
# Only created when table_export configuration is present

resource "aws_dynamodb_table_export" "this" {
  for_each = {
    for k, v in local.dynamodb_tables : k => v
    if can(v.config.table_export)
  }

  table_arn         = module.dynamodb_table[each.key].dynamodb_table_arn
  s3_bucket         = try(each.value.config.table_export.s3_bucket, "")
  s3_prefix         = try(each.value.config.table_export.s3_prefix, null)
  s3_bucket_owner   = try(each.value.config.table_export.s3_bucket_owner, null)
  export_format     = try(each.value.config.table_export.export_format, "DYNAMODB_JSON")
  export_time       = try(each.value.config.table_export.export_time, null)
  export_type       = try(each.value.config.table_export.export_type, "FULL_EXPORT")
  s3_sse_algorithm  = try(each.value.config.table_export.s3_sse_algorithm, null)
  s3_sse_kms_key_id = try(each.value.config.table_export.s3_sse_kms_key_id, null)

  dynamic "incremental_export_specification" {
    for_each = try(each.value.config.table_export.export_type, "FULL_EXPORT") == "INCREMENTAL_EXPORT" ? [each.value.config.table_export.incremental_export_specification] : []

    content {
      export_from_time = try(incremental_export_specification.value.export_from_time, null)
      export_to_time   = try(incremental_export_specification.value.export_to_time, null)
      export_view_type = try(incremental_export_specification.value.export_view_type, null)
    }
  }
}

################################################################################
# Validation Resources
################################################################################
# Since lifecycle preconditions are not supported in module blocks, we create
# terraform_data resources to validate configuration parameters before deployment

resource "terraform_data" "dynamodb_validation" {
  for_each = local.dynamodb_tables

  lifecycle {
    # Ensure create_table is specified
    precondition {
      condition     = can(each.value.create_table)
      error_message = "The 'create_table' key must be specified for DynamoDB table '${each.key}'. Set to true or false."
    }

    # Ensure hash_key is specified
    precondition {
      condition     = can(each.value.config.hash_key) || can(local.dynamodb_defaults.hash_key)
      error_message = "The 'hash_key' must be specified in config for DynamoDB table '${each.key}'."
    }

    # Ensure attributes is specified and is a list
    precondition {
      condition = (
        can(each.value.config.attributes) || can(local.dynamodb_defaults.attributes)
      ) && can(tolist(try(each.value.config.attributes, local.dynamodb_defaults.attributes, [])))
      error_message = "The 'attributes' must be specified as a list for DynamoDB table '${each.key}'."
    }

    # Ensure attributes list includes the hash_key
    precondition {
      condition = contains(
        [for attr in try(each.value.config.attributes, local.dynamodb_defaults.attributes, []) : attr.name],
        try(each.value.config.hash_key, local.dynamodb_defaults.hash_key, "")
      )
      error_message = "The 'attributes' list for DynamoDB table '${each.key}' must include an entry for the hash_key '${try(each.value.config.hash_key, local.dynamodb_defaults.hash_key, "")}'."
    }

    # Ensure attributes list includes the range_key if specified
    precondition {
      condition = (
        !can(each.value.config.range_key) && !can(local.dynamodb_defaults.range_key)
        ) || contains(
        [for attr in try(each.value.config.attributes, local.dynamodb_defaults.attributes, []) : attr.name],
        try(each.value.config.range_key, local.dynamodb_defaults.range_key, "")
      )
      error_message = "The 'attributes' list for DynamoDB table '${each.key}' must include an entry for the range_key '${try(each.value.config.range_key, local.dynamodb_defaults.range_key, "")}'."
    }

    # Ensure billing_mode is valid
    precondition {
      condition = contains(
        ["PROVISIONED", "PAY_PER_REQUEST"],
        try(each.value.config.billing_mode, local.dynamodb_defaults.billing_mode, "PAY_PER_REQUEST")
      )
      error_message = "The 'billing_mode' for DynamoDB table '${each.key}' must be 'PROVISIONED' or 'PAY_PER_REQUEST'. Current value: ${try(each.value.config.billing_mode, local.dynamodb_defaults.billing_mode, "PAY_PER_REQUEST")}."
    }

    # Ensure read_capacity and write_capacity are only used with PROVISIONED billing
    precondition {
      condition = !(
        try(each.value.config.billing_mode, local.dynamodb_defaults.billing_mode, "PAY_PER_REQUEST") == "PAY_PER_REQUEST" &&
        (can(each.value.config.read_capacity) || can(each.value.config.write_capacity))
      )
      error_message = "Cannot specify 'read_capacity' or 'write_capacity' when 'billing_mode' is 'PAY_PER_REQUEST' for DynamoDB table '${each.key}'. Set 'billing_mode' to 'PROVISIONED' or remove capacity settings."
    }

    # Ensure stream_view_type is specified when stream_enabled is true
    precondition {
      condition = !(
        try(each.value.config.stream_enabled, local.dynamodb_defaults.stream_enabled, false) &&
        !can(each.value.config.stream_view_type) && !can(local.dynamodb_defaults.stream_view_type)
      )
      error_message = "Must specify 'stream_view_type' when 'stream_enabled' is true for DynamoDB table '${each.key}'. Valid values: KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
    }

    # Ensure custom-key and explicit server_side_encryption_kms_key_arn are not both specified
    precondition {
      condition = !(
        try(each.value.config["custom-key"], false) &&
        can(each.value.config.server_side_encryption_kms_key_arn)
      )
      error_message = "Cannot specify both 'custom-key' and 'server_side_encryption_kms_key_arn' for DynamoDB table '${each.key}'. Use 'custom-key: true' for tag-based KMS lookup or provide an explicit ARN, not both."
    }

    # Ensure custom-key has a matching KMS key with the correct purpose tag
    precondition {
      condition = !(
        try(each.value.config["custom-key"], false) &&
        !contains(keys(local.kms_keys_by_purpose), each.key)
      )
      error_message = "DynamoDB table '${each.key}' has 'custom-key' set to true but no KMS key with a 'purpose' tag matching '${each.key}' was found. Ensure a KMS key is defined with tags: { purpose: \"${each.key}\" }."
    }

    # Ensure table_export has point_in_time_recovery_enabled
    precondition {
      condition = !(
        can(each.value.config.table_export) &&
        !try(each.value.config.point_in_time_recovery_enabled, local.dynamodb_defaults.point_in_time_recovery_enabled, false)
      )
      error_message = "DynamoDB table '${each.key}' has 'table_export' configured but 'point_in_time_recovery_enabled' is not true. Point-in-time recovery must be enabled for table exports."
    }

    # Ensure table_export has s3_bucket specified
    precondition {
      condition = !(
        can(each.value.config.table_export) &&
        !can(each.value.config.table_export.s3_bucket)
      )
      error_message = "The 'table_export.s3_bucket' must be specified for DynamoDB table '${each.key}' when table_export is configured."
    }

    # Ensure table_class is valid if specified
    precondition {
      condition = (
        !can(each.value.config.table_class) && !can(local.dynamodb_defaults.table_class)
        ) || contains(
        ["STANDARD", "STANDARD_INFREQUENT_ACCESS"],
        try(each.value.config.table_class, local.dynamodb_defaults.table_class, "STANDARD")
      )
      error_message = "The 'table_class' for DynamoDB table '${each.key}' must be 'STANDARD' or 'STANDARD_INFREQUENT_ACCESS'. Current value: ${try(each.value.config.table_class, local.dynamodb_defaults.table_class, "STANDARD")}."
    }
  }
}
