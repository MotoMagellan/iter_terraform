# Precondition Tests

Terraform native tests that validate all `lifecycle { precondition {} }` checks across the module's resource types.

## Test Files

| File | Resource | Preconditions |
|------|----------|---------------|
| `vpc_preconditions.tftest.hcl` | `terraform_data.vpc_config_validation` | 3 |
| `kms_preconditions.tftest.hcl` | `terraform_data.kms_validation` | 8 |
| `s3_preconditions.tftest.hcl` | `terraform_data.s3_validation` | 10 |
| `secrets_preconditions.tftest.hcl` | `terraform_data.secrets_validation` | 11 |
| `dynamo_preconditions.tftest.hcl` | `terraform_data.dynamodb_validation` | 13 |

Each file contains one positive test (valid config passes all preconditions) and one negative test per precondition.

## Running Tests

```bash
# Run all tests
terraform test

# Run a single test file
terraform test -filter=tests/vpc_preconditions.tftest.hcl

# Run with verbose output (shows plan details on failure)
terraform test -verbose

# Combine filter and verbose
terraform test -verbose -filter=tests/kms_preconditions.tftest.hcl
```

## How the Tests Work

- **Mock providers**: All tests use `mock_provider` for `aws`, `github`, and `gitlab` so no real credentials or API calls are needed.
- **Config injection**: Each `run` block uses `override_data` to inject YAML into `data.github_repository_file.github_infra_configs`, simulating a config file with specific invalid values.
- **Module isolation**: `override_module` prevents downstream module internals from evaluating, isolating the precondition logic.
- **Assertions**: `expect_failures` references the `terraform_data.*_validation` resource to assert that the precondition fires.
- All tests use `command = plan` since preconditions are evaluated at plan time.
