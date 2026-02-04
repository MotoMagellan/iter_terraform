# tests/s3_preconditions.tftest.hcl
# Validates all 10 preconditions on terraform_data.s3_validation (iter_s3.tf)

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
# Positive test: valid S3 config passes all preconditions
# ------------------------------------------------------------------------------
run "valid_s3_config_passes" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              versioning:
                enabled: true
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }
}

# ------------------------------------------------------------------------------
# Precondition 1 (iter_s3.tf L165-167):
# Cannot specify both bucket and bucket_prefix
# Expected error: "Cannot specify both 'bucket' and 'bucket_prefix' for S3
#   bucket 'test-bucket'. Choose one or the other."
# ------------------------------------------------------------------------------
run "s3_bucket_and_prefix_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              bucket: "my-bucket"
              bucket_prefix: "my-prefix-"
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 2 (iter_s3.tf L171-176):
# Cannot use ACL when object_ownership is BucketOwnerEnforced (the default)
# Expected error: "Cannot use 'acl' parameter when 'object_ownership' is set to
#   'BucketOwnerEnforced' for S3 bucket 'test-bucket'..."
# ------------------------------------------------------------------------------
run "s3_acl_incompatible_with_bucket_owner_enforced" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              acl: "private"
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 3 (iter_s3.tf L180-186):
# Cannot use grant when object_ownership is BucketOwnerEnforced (the default)
# Expected error: "Cannot use 'grant' parameter when 'object_ownership' is set
#   to 'BucketOwnerEnforced' for S3 bucket 'test-bucket'..."
# ------------------------------------------------------------------------------
run "s3_grant_incompatible_with_bucket_owner_enforced" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              grant:
                - id: "test-canonical-id"
                  type: "CanonicalUser"
                  permissions:
                    - "FULL_CONTROL"
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 4 (iter_s3.tf L190-197):
# Cannot specify both ACL and grant
# Expected error: "Cannot specify both 'acl' and 'grant' for S3 bucket
#   'test-bucket'. Choose one or the other."
# Note: object_ownership set to ObjectWriter to avoid triggering preconditions 2/3
# ------------------------------------------------------------------------------
run "s3_acl_and_grant_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              object_ownership: "ObjectWriter"
              acl: "private"
              grant:
                - id: "test-canonical-id"
                  type: "CanonicalUser"
                  permissions:
                    - "FULL_CONTROL"
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 5 (iter_s3.tf L200-207):
# Must set object_lock_enabled to true when object_lock_configuration is specified
# Expected error: "Must set 'object_lock_enabled' to true when
#   'object_lock_configuration' is specified for S3 bucket 'test-bucket'."
# ------------------------------------------------------------------------------
run "s3_object_lock_config_requires_enabled" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              object_lock_configuration:
                rule:
                  default_retention:
                    mode: "GOVERNANCE"
                    days: 1
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 6 (iter_s3.tf L210-215):
# Directory bucket parameters can only be used when is_directory_bucket is true
# Expected error: "Directory bucket parameters ('data_redundancy',
#   'availability_zone_id', 'metadata_inventory_table_configuration_state') can
#   only be used when 'is_directory_bucket' is true..."
# ------------------------------------------------------------------------------
run "s3_directory_params_require_directory_bucket" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              data_redundancy: "SingleAvailabilityZone"
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 7 (iter_s3.tf L219-224):
# Must specify availability_zone_id when is_directory_bucket is true
# Expected error: "Must specify 'availability_zone_id' when
#   'is_directory_bucket' is true for S3 bucket 'test-bucket'."
# ------------------------------------------------------------------------------
run "s3_directory_bucket_requires_az_id" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              is_directory_bucket: true
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 8 (iter_s3.tf L228-233):
# Must specify allowed_kms_key_arn when attach_deny_incorrect_kms_key_sse is true
# Expected error: "Must specify 'allowed_kms_key_arn' when
#   'attach_deny_incorrect_kms_key_sse' is true for S3 bucket 'test-bucket'."
# ------------------------------------------------------------------------------
run "s3_deny_kms_sse_requires_allowed_key_arn" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              attach_deny_incorrect_kms_key_sse: true
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 9 (iter_s3.tf L237-242):
# Cannot specify both custom-key and server_side_encryption_configuration
# Expected error: "Cannot specify both 'custom-key' and
#   'server_side_encryption_configuration' for S3 bucket 'test-bucket'..."
# Note: No companion KMS key included. This co-triggers precondition 10
#   (custom-key requires matching KMS purpose tag) since no KMS key exists.
#   Both failures are on the same terraform_data.s3_validation resource,
#   so expect_failures catches them.
# ------------------------------------------------------------------------------
run "s3_custom_key_and_sse_config_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              custom-key: true
              server_side_encryption_configuration:
                rule:
                  apply_server_side_encryption_by_default:
                    sse_algorithm: "AES256"
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 10 (iter_s3.tf L247-251):
# custom-key requires a KMS key with a matching purpose tag
# Expected error: "S3 bucket 'test-bucket' has 'custom-key' set to true but no
#   KMS key with a 'purpose' tag matching 'test-bucket' was found..."
# ------------------------------------------------------------------------------
run "s3_custom_key_requires_matching_kms_purpose_tag" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        s3:
          buckets:
            test-bucket:
              custom-key: true
      EOT
    }
  }

  override_module {
    target = module.s3_bucket
  }

  expect_failures = [
    terraform_data.s3_validation,
  ]
}
