# tests/kms_preconditions.tftest.hcl
# Validates all 8 preconditions on terraform_data.kms_validation (iter_kms.tf)

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
# Positive test: valid KMS config passes all preconditions
# ------------------------------------------------------------------------------
run "valid_kms_config_passes" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            description: "Test KMS key"
            deletion_window_in_days: 30
            enable_key_rotation: true
      EOT
    }
  }

  override_module {
    target = module.kms
  }
}

# ------------------------------------------------------------------------------
# Precondition 1 (iter_kms.tf L131-137):
# deletion_window_in_days must be between 7-30
# Expected error: "The 'deletion_window_in_days' for KMS key 'test-key' must be
#   between 7-30 days. Current value: 5."
# ------------------------------------------------------------------------------
run "kms_deletion_window_out_of_range" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            deletion_window_in_days: 5
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 2 (iter_kms.tf L140-145):
# Key rotation can only be enabled for ENCRYPT_DECRYPT key_usage
# Expected error: "Key rotation can only be enabled for symmetric encryption
#   keys (key_usage = ENCRYPT_DECRYPT) for KMS key 'test-key'..."
# Note: customer_master_key_spec kept as SYMMETRIC_DEFAULT to avoid triggering
#   precondition 3
# ------------------------------------------------------------------------------
run "kms_rotation_requires_encrypt_decrypt_usage" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            enable_key_rotation: true
            key_usage: "SIGN_VERIFY"
            customer_master_key_spec: "SYMMETRIC_DEFAULT"
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 3 (iter_kms.tf L149-155):
# Key rotation can only be enabled for SYMMETRIC_DEFAULT customer_master_key_spec
# Expected error: "Key rotation can only be enabled for symmetric keys
#   (customer_master_key_spec = SYMMETRIC_DEFAULT) for KMS key 'test-key'..."
# Note: key_usage kept as ENCRYPT_DECRYPT to avoid triggering precondition 2
# ------------------------------------------------------------------------------
run "kms_rotation_requires_symmetric_key_spec" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            enable_key_rotation: true
            key_usage: "ENCRYPT_DECRYPT"
            customer_master_key_spec: "RSA_2048"
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 4 (iter_kms.tf L158-163):
# Cannot specify rotation_period_in_days when enable_key_rotation is false
# Expected error: "Cannot specify 'rotation_period_in_days' when
#   'enable_key_rotation' is false for KMS key 'test-key'..."
# ------------------------------------------------------------------------------
run "kms_rotation_period_requires_rotation_enabled" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            enable_key_rotation: false
            rotation_period_in_days: 180
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 5 (iter_kms.tf L167-175):
# rotation_period_in_days must be between 90-2560 when specified
# Expected error: "The 'rotation_period_in_days' for KMS key 'test-key' must be
#   between 90-2560 days when specified. Current value: 50."
# ------------------------------------------------------------------------------
run "kms_rotation_period_out_of_range" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            enable_key_rotation: true
            rotation_period_in_days: 50
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 6 (iter_kms.tf L179-184):
# Custom key stores can only be used with SYMMETRIC_DEFAULT
# Expected error: "Custom key stores can only be used with symmetric keys
#   (customer_master_key_spec = SYMMETRIC_DEFAULT) for KMS key 'test-key'."
# Note: enable_key_rotation set to false to avoid triggering preconditions 2/3
# ------------------------------------------------------------------------------
run "kms_custom_key_store_requires_symmetric" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            custom_key_store_id: "cks-test123"
            customer_master_key_spec: "RSA_2048"
            key_usage: "SIGN_VERIFY"
            enable_key_rotation: false
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 7 (iter_kms.tf L188-193):
# Cannot use multi_region with custom_key_store_id
# Expected error: "Cannot use 'multi_region' with 'custom_key_store_id' for KMS
#   key 'test-key'. Multi-region keys cannot be created in a custom key store."
# Note: customer_master_key_spec kept as SYMMETRIC_DEFAULT to avoid triggering
#   precondition 6
# ------------------------------------------------------------------------------
run "kms_multi_region_incompatible_with_custom_store" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            multi_region: true
            custom_key_store_id: "cks-test123"
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 8 (iter_kms.tf L197-203):
# aliases must be a list of strings
# Expected error: "The 'aliases' parameter must be a list of strings for KMS
#   key 'test-key'."
# ------------------------------------------------------------------------------
run "kms_aliases_must_be_list" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        kms:
          test-key:
            aliases: "not-a-list"
      EOT
    }
  }

  override_module {
    target = module.kms
  }

  expect_failures = [
    terraform_data.kms_validation,
  ]
}
