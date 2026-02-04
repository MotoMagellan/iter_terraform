# tests/dynamo_preconditions.tftest.hcl
# Validates all 13 preconditions on terraform_data.dynamodb_validation (iter_dynamo.tf)

mock_provider "aws" {}
mock_provider "github" {}
mock_provider "gitlab" {}

variables {
  config_repo_files = {
    github = [{
      repository = "test/repo"
      file_path  = "infra.yml"
    }]
    gitlab = []
  }
  config_defaults = {
    service = {
      service    = "github"
      repository = "test/defaults"
      file_path  = "defaults.yml"
    }
  }
}

# ------------------------------------------------------------------------------
# Positive test: valid DynamoDB config passes all preconditions
# ------------------------------------------------------------------------------
run "valid_dynamodb_config_passes" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              billing_mode: "PAY_PER_REQUEST"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }
}

# ------------------------------------------------------------------------------
# Precondition 1 (iter_dynamo.tf L214-216):
# The create_table key must be specified
# Expected error: "The 'create_table' key must be specified for DynamoDB table
#   'test-table'. Set to true or false."
# ------------------------------------------------------------------------------
run "dynamo_create_table_required" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 2 (iter_dynamo.tf L220-222):
# hash_key must be specified in config
# Expected error: "The 'hash_key' must be specified in config for DynamoDB table
#   'test-table'."
# ------------------------------------------------------------------------------
run "dynamo_hash_key_required" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              attributes:
                - name: "id"
                  type: "S"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 3 (iter_dynamo.tf L226-230):
# attributes must be specified as a list
# Expected error: "The 'attributes' must be specified as a list for DynamoDB
#   table 'test-table'."
# Note: Omitting attributes entirely (rather than setting to a non-list value)
#   because setting attributes to a string like "not-a-list" causes precondition
#   4's for-expression to error when iterating it. Terraform evaluates all
#   preconditions in parallel, so precondition 3 detects the issue but
#   precondition 4 errors before it can evaluate to true/false.
#   This also co-triggers precondition 4 (attributes must include hash_key)
#   since the empty default list won't contain the hash_key.
# ------------------------------------------------------------------------------
run "dynamo_attributes_required_as_list" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 4 (iter_dynamo.tf L234-239):
# attributes list must include an entry for the hash_key
# Expected error: "The 'attributes' list for DynamoDB table 'test-table' must
#   include an entry for the hash_key 'user_id'."
# ------------------------------------------------------------------------------
run "dynamo_attributes_must_include_hash_key" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "user_id"
              attributes:
                - name: "other_field"
                  type: "S"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 5 (iter_dynamo.tf L243-250):
# attributes list must include an entry for the range_key when specified
# Expected error: "The 'attributes' list for DynamoDB table 'test-table' must
#   include an entry for the range_key 'sk'."
# ------------------------------------------------------------------------------
run "dynamo_attributes_must_include_range_key" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              range_key: "sk"
              attributes:
                - name: "id"
                  type: "S"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 6 (iter_dynamo.tf L254-259):
# billing_mode must be PROVISIONED or PAY_PER_REQUEST
# Expected error: "The 'billing_mode' for DynamoDB table 'test-table' must be
#   'PROVISIONED' or 'PAY_PER_REQUEST'. Current value: INVALID."
# ------------------------------------------------------------------------------
run "dynamo_billing_mode_must_be_valid" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              billing_mode: "INVALID"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 7 (iter_dynamo.tf L263-268):
# Cannot specify read_capacity or write_capacity with PAY_PER_REQUEST billing
# Expected error: "Cannot specify 'read_capacity' or 'write_capacity' when
#   'billing_mode' is 'PAY_PER_REQUEST' for DynamoDB table 'test-table'..."
# ------------------------------------------------------------------------------
run "dynamo_capacity_requires_provisioned_billing" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              billing_mode: "PAY_PER_REQUEST"
              read_capacity: 10
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 8 (iter_dynamo.tf L272-277):
# Must specify stream_view_type when stream_enabled is true
# Expected error: "Must specify 'stream_view_type' when 'stream_enabled' is true
#   for DynamoDB table 'test-table'. Valid values: KEYS_ONLY, NEW_IMAGE,
#   OLD_IMAGE, NEW_AND_OLD_IMAGES."
# ------------------------------------------------------------------------------
run "dynamo_stream_view_type_required_when_streaming" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              stream_enabled: true
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 9 (iter_dynamo.tf L281-286):
# Cannot specify both custom-key and server_side_encryption_kms_key_arn
# Expected error: "Cannot specify both 'custom-key' and
#   'server_side_encryption_kms_key_arn' for DynamoDB table 'test-table'..."
# Note: No companion KMS key included. This co-triggers precondition 10
#   (custom-key requires matching KMS purpose tag) since no KMS key exists.
#   Both failures are on the same terraform_data.dynamodb_validation resource,
#   so expect_failures catches them.
# ------------------------------------------------------------------------------
run "dynamo_custom_key_and_kms_arn_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              custom-key: true
              server_side_encryption_kms_key_arn: "arn:aws:kms:us-east-1:123456789012:key/test-key-id"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 10 (iter_dynamo.tf L290-295):
# custom-key requires a KMS key with a matching purpose tag
# Expected error: "DynamoDB table 'test-table' has 'custom-key' set to true but
#   no KMS key with a 'purpose' tag matching 'test-table' was found..."
# ------------------------------------------------------------------------------
run "dynamo_custom_key_requires_matching_kms_purpose_tag" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              custom-key: true
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 11 (iter_dynamo.tf L299-304):
# table_export requires point_in_time_recovery_enabled to be true
# Expected error: "DynamoDB table 'test-table' has 'table_export' configured but
#   'point_in_time_recovery_enabled' is not true..."
# ------------------------------------------------------------------------------
run "dynamo_table_export_requires_pitr" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              table_export:
                s3_bucket: "my-export-bucket"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
    outputs = {
      dynamodb_table_arn                  = "arn:aws:dynamodb:us-east-1:123456789012:table/test-table"
      dynamodb_table_id                   = "test-table"
      dynamodb_table_stream_arn           = ""
      dynamodb_table_stream_label         = ""
      dynamodb_table_replicas             = {}
      dynamodb_table_replica_arns         = {}
      dynamodb_table_replica_stream_arns  = {}
      dynamodb_table_replica_stream_labels = {}
    }
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 12 (iter_dynamo.tf L308-313):
# table_export must have s3_bucket specified
# Expected error: "The 'table_export.s3_bucket' must be specified for DynamoDB
#   table 'test-table' when table_export is configured."
# Note: point_in_time_recovery_enabled set to true to avoid triggering
#   precondition 11
# ------------------------------------------------------------------------------
run "dynamo_table_export_requires_s3_bucket" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              point_in_time_recovery_enabled: true
              table_export:
                export_format: "DYNAMODB_JSON"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
    outputs = {
      dynamodb_table_arn                  = "arn:aws:dynamodb:us-east-1:123456789012:table/test-table"
      dynamodb_table_id                   = "test-table"
      dynamodb_table_stream_arn           = ""
      dynamodb_table_stream_label         = ""
      dynamodb_table_replicas             = {}
      dynamodb_table_replica_arns         = {}
      dynamodb_table_replica_stream_arns  = {}
      dynamodb_table_replica_stream_labels = {}
    }
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 13 (iter_dynamo.tf L317-324):
# table_class must be STANDARD or STANDARD_INFREQUENT_ACCESS
# Expected error: "The 'table_class' for DynamoDB table 'test-table' must be
#   'STANDARD' or 'STANDARD_INFREQUENT_ACCESS'. Current value: INVALID."
# ------------------------------------------------------------------------------
run "dynamo_table_class_must_be_valid" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        dynamodb-tables:
          test-table:
            create_table: true
            config:
              hash_key: "id"
              attributes:
                - name: "id"
                  type: "S"
              table_class: "INVALID"
      EOT
    }
  }

  override_module {
    target = module.dynamodb_table
  }

  expect_failures = [
    terraform_data.dynamodb_validation,
  ]
}
