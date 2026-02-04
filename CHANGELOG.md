# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Precondition Test Suite**: Added 50 Terraform native tests validating all lifecycle precondition checks across 5 resource types
  - `tests/vpc_preconditions.tftest.hcl` — 4 tests (1 positive + 3 preconditions)
  - `tests/kms_preconditions.tftest.hcl` — 9 tests (1 positive + 8 preconditions)
  - `tests/s3_preconditions.tftest.hcl` — 11 tests (1 positive + 10 preconditions)
  - `tests/secrets_preconditions.tftest.hcl` — 12 tests (1 positive + 11 preconditions)
  - `tests/dynamo_preconditions.tftest.hcl` — 14 tests (1 positive + 13 preconditions)
  - Tests use `mock_provider`, `override_data`, and `override_module` — no AWS credentials or API calls required
  - Added `tests/README.md` with usage instructions

### Changed

- Restructured `output "kms_keys"` in `outputs.tf` to explicitly map non-sensitive fields, avoiding sensitivity propagation from the KMS module's `grants` output
- Added new `output "kms_key_grants"` (sensitive) for consumers that need grant information
- Fixed `data.tf` `for_each` expressions on `github_repository_file` and `gitlab_repository_file` data sources — replaced `toset()` on object lists with map comprehensions keyed by file path
- Wrapped `s3_bucket` reference in `aws_dynamodb_table_export` with `try()` to allow the precondition to validate missing values before expression evaluation

- **AWS KMS Key Support**: Added configuration-driven KMS key management through new `iter_kms.tf` module
  - Key creation using `terraform-aws-modules/kms/aws` module (v4.x)
  - Support for key configuration parameters including:
    - Key specifications (key_usage, customer_master_key_spec, key_spec)
    - Automatic key rotation with configurable rotation period
    - Multi-region key support
    - Custom key store integration (CloudHSM)
    - Key state management (enable/disable)
    - Bypass policy lockout safety check
  - Configuration structure uses `kms` as the top-level key with KMS key name as sub-key:
    ```yaml
    kms:
      key-name:
        description: "My KMS key"
        aliases: ["alias/my-key"]
        resource_policy:
          AllowRootAccess:
            sid: "Enable IAM User Permissions"
            effect: "Allow"
            principals:
              - type: "AWS"
                identifiers: ["arn:aws:iam::123456789012:root"]
            actions: ["kms:*"]
            resources: ["*"]
    ```
  - Alias management:
    - Supports multiple aliases per key via `aliases` list
    - Computed aliases for dynamic values
    - Optional name prefix for aliases
  - Resource policy implementation:
    - Uses module's `key_statements` parameter
    - Accepts `resource_policy` as map of IAM statement maps
    - Automatically disables default policy when custom `resource_policy` is provided
    - Supports simplified IAM role-based access via `key_owners`, `key_administrators`, `key_users`, `key_service_users`
    - Route53 DNSSEC policy support
  - Grant management for fine-grained access control
  - Implemented 8 validation checks using `terraform_data` resources with lifecycle preconditions:
    - Deletion window validation (must be 7-30 days)
    - Key rotation compatibility (symmetric encryption keys only)
    - Key spec compatibility with rotation
    - Rotation period validation (90-2560 days when specified)
    - Rotation parameter dependencies
    - Custom key store symmetric key requirement
    - Multi-region and custom key store mutual exclusivity
    - Alias type validation (must be list)
  - Inherits defaults from `local.defaults.kms` following established pattern
  - Full integration with global tagging strategy
  - Updated basic and complete examples with KMS outputs
  - Complete example includes DynamoDB-oriented KMS key configuration with `Purpose` and `RelatedResource` tags

- **AWS Secrets Manager Support**: Added comprehensive secrets management through new `iter_secrets.tf` module
  - Configuration-driven secret creation using `terraform-aws-modules/secrets-manager/aws` module (v2.x)
  - Support for 20+ Secrets Manager configuration parameters including:
    - Basic secret configuration (name, description, region)
    - Encryption with AWS KMS keys
    - Secret value management (string, binary, write-only ephemeral)
    - Ephemeral random password generation
    - Secret replication across regions
    - Resource policy attachment via `secret_resource_policy` configuration key
    - Automatic rotation with Lambda function integration
    - Configurable recovery window (0 for immediate deletion, 7-30 days)
    - Version staging and secret versioning
  - Custom KMS key integration via `custom-key` boolean:
    - When `true`, automatically looks up a KMS key by matching the `purpose` tag to the secret key name
    - Automatically sets `kms_key_id` with the looked-up KMS key ARN
    - Leverages global `kms_keys_by_purpose` local in `main.tf` for tag-based KMS key resolution
    - Validates that a matching KMS key exists before deployment
    - Mutually exclusive with explicit `kms_key_id` — use one or the other
    - Explicit `kms_key_id` ARNs remain fully supported for externally-managed keys
  - Configuration structure follows established pattern:
    ```yaml
    secrets:
      secrets:
        secret-name:
          description: "My secret"
          secret_string: "value"
          custom-key: true  # automatic KMS key lookup by 'purpose' tag
          secret_resource_policy:  # Optional IAM policy as map of statements
            AllowReadAccess:
              sid: "AllowReadAccess"
              effect: "Allow"
              principals:
                - type: "AWS"
                  identifiers: ["arn:aws:iam::123456789012:role/MyRole"]
              actions: ["secretsmanager:GetSecretValue"]
    ```
  - Resource policy implementation:
    - Uses module's built-in `policy_statements` parameter
    - Accepts `secret_resource_policy` as map of IAM statement maps
    - Automatically enables policy creation when `secret_resource_policy` is present
    - No default policy - only created when explicitly configured
  - Implemented 11 validation checks using `terraform_data` resources with lifecycle preconditions:
    - Mutual exclusivity between `name` and `name_prefix`
    - Single secret value type validation (only one of: secret_string, secret_binary, secret_string_wo, create_random_password)
    - Recovery window validation (must be 0 or 7-30 days)
    - Rotation lambda ARN requirement when rotation enabled
    - Rotation-specific parameter validation (rotation_rules, rotate_immediately only valid when rotation enabled)
    - Write-only secret version parameter dependencies
    - Random password parameter dependencies
    - Replica region validation
    - `custom-key` and explicit `kms_key_id` mutually exclusive
    - `custom-key` requires matching KMS key with `purpose` tag
  - Inherits defaults from `local.defaults.secrets` following established pattern
  - Full integration with global tagging strategy
  - Supports ephemeral resources for enhanced secret security (secrets not stored in state)

- **AWS DynamoDB Table Support**: Added configuration-driven DynamoDB table management through new `iter_dynamo.tf` module
  - Table creation using `terraform-aws-modules/dynamodb-table/aws` module (v5.x)
  - Configuration structure uses `dynamodb-tables` as the top-level key with table name as sub-key:
    ```yaml
    dynamodb-tables:
      table-name:
        create_table: true
        config:
          hash_key: "id"
          attributes:
            - name: "id"
              type: "S"
          billing_mode: "PAY_PER_REQUEST"
          custom-key: true
    ```
  - First-class keys outside `config`: `name` (optional table name override), `create_table` (required)
  - Support for 25+ DynamoDB configuration parameters under `config` including:
    - Key schema (hash_key, range_key, attributes)
    - Capacity configuration (billing_mode, read/write capacity)
    - Point-in-time recovery with configurable retention period
    - TTL configuration
    - Global and local secondary indexes
    - DynamoDB Streams with configurable view types
    - Server-side encryption with AWS-managed or customer-managed KMS keys
    - Table class selection (STANDARD, STANDARD_INFREQUENT_ACCESS)
    - Deletion protection
    - Autoscaling for read/write capacity and indexes
    - On-demand and warm throughput configuration
    - Global table replication across regions
    - Table import from S3
  - Custom KMS key integration via `custom-key` boolean:
    - When `true`, automatically looks up a KMS key by matching the `purpose` tag to the table key name
    - Automatically enables server-side encryption when `custom-key` is set
    - Leverages global `kms_keys_by_purpose` local in `main.tf` for tag-based KMS key resolution
    - Validates that a matching KMS key exists before deployment
  - Resource policy support:
    - Accepts `resource_policy` as either a JSON string or a map (automatically jsonencoded)
    - Supports the module's `__DYNAMODB_TABLE_ARN__` placeholder for self-referencing policies
  - CloudWatch Contributor Insights (`aws_dynamodb_contributor_insights`):
    - Enabled per-table via `contributor_insights.enabled` in config
    - Optional `index_name` for GSI-level insights
  - DynamoDB Table Export to S3 (`aws_dynamodb_table_export`):
    - Full and incremental export support
    - Configurable S3 destination (bucket, prefix, owner)
    - Export format selection (DYNAMODB_JSON, ION)
    - S3 server-side encryption options (AES256, KMS)
    - Dynamic `incremental_export_specification` block for incremental exports
  - Implemented 13 validation checks using `terraform_data` resources with lifecycle preconditions:
    - `create_table` must be specified
    - `hash_key` required
    - `attributes` required and must be a list
    - `attributes` must include hash_key entry
    - `attributes` must include range_key entry (when range_key specified)
    - `billing_mode` validation (PROVISIONED or PAY_PER_REQUEST)
    - Read/write capacity only valid with PROVISIONED billing
    - `stream_view_type` required when streams enabled
    - `custom-key` and explicit KMS ARN mutually exclusive
    - `custom-key` requires matching KMS key with `purpose` tag
    - Table export requires point-in-time recovery enabled
    - Table export requires `s3_bucket` specified
    - `table_class` validation (STANDARD or STANDARD_INFREQUENT_ACCESS)
  - Inherits defaults from `local.defaults["dynamodb-tables"]` following established pattern
  - Full integration with global tagging strategy
  - Updated basic and complete examples with DynamoDB outputs and YAML configuration examples
  - Added global `kms_keys_by_purpose` local to `main.tf` for cross-resource KMS key tag-based lookups

- **S3 Bucket Support**: Added comprehensive S3 bucket management through new `iter_s3.tf` module
  - Configuration-driven S3 bucket creation using `terraform-aws-modules/s3-bucket/aws` module (v5.x)
  - Support for 40+ S3 bucket configuration parameters including:
    - Access control (ACL, public access blocks, object ownership)
    - Security features (encryption, versioning, object lock)
    - Lifecycle rules and intelligent tiering
    - CORS, logging, and website configuration
    - Multiple policy attachments (ELB, CloudTrail, WAF, etc.)
    - Directory buckets (S3 Express One Zone)
  - Custom KMS key integration via `custom-key` boolean:
    - When `true`, automatically looks up a KMS key by matching the `purpose` tag to the bucket key name
    - Automatically configures server-side encryption with `aws:kms` algorithm, bucket key enabled, and the looked-up KMS key ARN
    - Leverages global `kms_keys_by_purpose` local in `main.tf` for tag-based KMS key resolution
    - Validates that a matching KMS key exists before deployment
    - Mutually exclusive with explicit `server_side_encryption_configuration` — use one or the other
    - Explicit `server_side_encryption_configuration` and `kms_key_id` ARNs remain fully supported for externally-managed keys
  - Configuration structure follows established pattern:
    ```yaml
    s3:
      buckets:
        bucket-name:
          custom-key: true  # automatic KMS key lookup by 'purpose' tag
          # bucket configuration options
    ```
  - Implemented 10 precondition validations to prevent misconfigurations:
    - Mutual exclusivity between `bucket` and `bucket_prefix`
    - Compatibility checks for ACL/grant usage with object ownership settings
    - Object lock configuration validation
    - Directory bucket parameter validation
    - KMS key requirements for encryption policies
    - `custom-key` and explicit `server_side_encryption_configuration` mutually exclusive
    - `custom-key` requires matching KMS key with `purpose` tag
  - Inherits defaults from `local.defaults.s3` similar to VPC defaults pattern
  - Full integration with global tagging strategy

## [0.1.0] - Initial Release

### Added

#### Core Infrastructure Framework
- **Configuration-Driven Architecture**: Generalized config-driven Terraform framework
  - Configuration loading from GitHub and GitLab repositories via dedicated data sources
  - Support for branch/ref specification per repository
  - Merged configuration system from multiple repositories
  - Dedicated data sources for loading default values separate from instance configurations
  - Global tagging support with tag inheritance across all resources

#### VPC Management (`iter_vpc.tf`)
- **VPC Module**: Comprehensive VPC management using `terraform-aws-modules/vpc/aws` module (v6.6.0)
  - Configuration structure using `vpcs` as top-level key with VPC name as sub-key
  - Support for multiple VPCs with customizable CIDR blocks
  - Intelligent CIDR calculation with `vpc_cidr_offset` for multi-VPC deployments
  - Automatic subnet CIDR calculation across 6 subnet types (private, public, database, elasticache, redshift, intra)
  - Configurable availability zone count with automatic subnet distribution
  - NAT Gateway support (single, per-AZ, or external IPs)
  - Internet Gateway and Egress-only Internet Gateway
  - IPv6 support with customizable prefixes per subnet type
  - VPN Gateway and Customer Gateway support
  - Comprehensive DNS and DHCP options configuration
  - Network ACLs with dedicated ACLs per subnet type
  - Security group management for default and custom groups
  - Route table management with subnet-specific configurations
  - Database, ElastiCache, and Redshift subnet groups
  - Granular tagging for all resource types with customizable naming
  - Defaults system with fallback hierarchy (VPC-specific → defaults → hardcoded)

- **VPC Flow Logs**: Optional VPC Flow Logs with CloudWatch/S3 integration
  - Configurable traffic type (ACCEPT, REJECT, ALL)
  - CloudWatch Log Group management with retention, KMS encryption
  - S3 destination support with Hive-compatible partitions
  - IAM role creation for logging

- **VPC Endpoints Module**: Using `terraform-aws-modules/vpc/aws//modules/vpc-endpoints` (v6.6.0)
  - Pre-configured service defaults for S3, DynamoDB, ECS, ECR, RDS
  - Automatic security group creation for interface endpoints
  - IAM policy documents restricting access to VPC traffic only
  - Supporting resources (IAM policies, RDS security groups)
  - Conditional endpoint creation and per-service customization

#### Documentation & Tooling
- README automation using terraform-docs tool
- Example configurations for VPC and VPC Endpoints
- Configuration structure documentation

### Changed

- README cleanup and examples improvement
- Modified defaults loading to use distinct file read with dedicated data sources

### Fixed

- Corrected lookups in VPC configuration
- README formatting fixes

[Unreleased]: https://github.com/your-org/iter-terraform/compare/HEAD...HEAD
