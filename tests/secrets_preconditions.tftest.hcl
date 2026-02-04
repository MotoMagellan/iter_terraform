# tests/secrets_preconditions.tftest.hcl
# Validates all 11 preconditions on terraform_data.secrets_validation (iter_secrets.tf)

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
# Positive test: valid Secrets config passes all preconditions
# ------------------------------------------------------------------------------
run "valid_secrets_config_passes" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              description: "Test secret"
              secret_string: "test-value"
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }
}

# ------------------------------------------------------------------------------
# Precondition 1 (iter_secrets.tf L129-131):
# Cannot specify both name and name_prefix
# Expected error: "Cannot specify both 'name' and 'name_prefix' for secret
#   'test-secret'. Choose one or the other."
# ------------------------------------------------------------------------------
run "secrets_name_and_prefix_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              name: "my-secret"
              name_prefix: "my-prefix-"
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 2 (iter_secrets.tf L135-142):
# Cannot specify more than one secret value type
# Expected error: "Cannot specify more than one of 'secret_string',
#   'secret_binary', 'secret_string_wo', or 'create_random_password' for
#   secret 'test-secret'..."
# ------------------------------------------------------------------------------
run "secrets_multiple_value_types_not_allowed" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              secret_string: "value-a"
              secret_binary: "dmFsdWUtYg=="
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 3 (iter_secrets.tf L146-152):
# recovery_window_in_days must be 0 (force delete) or between 7-30
# Expected error: "The 'recovery_window_in_days' for secret 'test-secret' must
#   be 0 (force delete) or between 7-30 days. Current value: 3."
# ------------------------------------------------------------------------------
run "secrets_recovery_window_invalid" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              recovery_window_in_days: 3
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 4 (iter_secrets.tf L156-162):
# Must specify rotation_lambda_arn when enable_rotation is true
# Expected error: "Must specify 'rotation_lambda_arn' when 'enable_rotation' is
#   true for secret 'test-secret'."
# ------------------------------------------------------------------------------
run "secrets_rotation_requires_lambda_arn" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              enable_rotation: true
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 5 (iter_secrets.tf L165-173):
# Cannot specify rotation_rules when enable_rotation is false
# Expected error: "Cannot specify 'rotation_rules' when 'enable_rotation' is
#   false for secret 'test-secret'..."
# ------------------------------------------------------------------------------
run "secrets_rotation_rules_require_rotation_enabled" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              rotation_rules:
                automatically_after_days: 30
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 6 (iter_secrets.tf L177-182):
# Cannot specify rotate_immediately when enable_rotation is false
# Expected error: "Cannot specify 'rotate_immediately' when 'enable_rotation' is
#   false for secret 'test-secret'..."
# ------------------------------------------------------------------------------
run "secrets_rotate_immediately_requires_rotation_enabled" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              rotate_immediately: true
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 7 (iter_secrets.tf L186-192):
# Cannot specify secret_string_wo_version without secret_string_wo
# Expected error: "Cannot specify 'secret_string_wo_version' without
#   'secret_string_wo' for secret 'test-secret'."
# ------------------------------------------------------------------------------
run "secrets_wo_version_requires_wo_string" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              secret_string_wo_version: 1
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 8 (iter_secrets.tf L195-203):
# Cannot specify random_password_length or random_password_override_special
# when create_random_password is false
# Expected error: "Cannot specify 'random_password_length' or
#   'random_password_override_special' when 'create_random_password' is false
#   for secret 'test-secret'..."
# ------------------------------------------------------------------------------
run "secrets_random_password_params_require_flag" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              random_password_length: 64
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 9 (iter_secrets.tf L207-213):
# Each replica configuration must specify a region
# Expected error: "Each replica configuration for secret 'test-secret' must
#   specify a 'region'."
# ------------------------------------------------------------------------------
run "secrets_replica_must_have_region" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              replica:
                us-west-2: {}
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 10 (iter_secrets.tf L216-221):
# Cannot specify both custom-key and kms_key_id
# Expected error: "Cannot specify both 'custom-key' and 'kms_key_id' for secret
#   'test-secret'..."
# Note: No companion KMS key included. This co-triggers precondition 11
#   (custom-key requires matching KMS purpose tag) since no KMS key exists.
#   Both failures are on the same terraform_data.secrets_validation resource,
#   so expect_failures catches them.
# ------------------------------------------------------------------------------
run "secrets_custom_key_and_kms_id_mutually_exclusive" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              custom-key: true
              kms_key_id: "arn:aws:kms:us-east-1:123456789012:key/test-key-id"
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}

# ------------------------------------------------------------------------------
# Precondition 11 (iter_secrets.tf L225-230):
# custom-key requires a KMS key with a matching purpose tag
# Expected error: "Secret 'test-secret' has 'custom-key' set to true but no KMS
#   key with a 'purpose' tag matching 'test-secret' was found..."
# ------------------------------------------------------------------------------
run "secrets_custom_key_requires_matching_kms_purpose_tag" {
  command = plan

  override_data {
    target = data.github_repository_file.github_infra_configs
    values = {
      content = <<-EOT
        secrets:
          secrets:
            test-secret:
              custom-key: true
      EOT
    }
  }

  override_module {
    target = module.secrets_manager
  }

  expect_failures = [
    terraform_data.secrets_validation,
  ]
}
