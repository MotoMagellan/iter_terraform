# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
  - Configuration structure follows established pattern:
    ```yaml
    secrets:
      secrets:
        secret-name:
          description: "My secret"
          secret_string: "value"
          kms_key_id: "arn:aws:kms:..."
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
  - Implemented 9 validation checks using `terraform_data` resources with lifecycle preconditions:
    - Mutual exclusivity between `name` and `name_prefix`
    - Single secret value type validation (only one of: secret_string, secret_binary, secret_string_wo, create_random_password)
    - Recovery window validation (must be 0 or 7-30 days)
    - Rotation lambda ARN requirement when rotation enabled
    - Rotation-specific parameter validation (rotation_rules, rotate_immediately only valid when rotation enabled)
    - Write-only secret version parameter dependencies
    - Random password parameter dependencies
    - Replica region validation
  - Inherits defaults from `local.defaults.secrets` following established pattern
  - Full integration with global tagging strategy
  - Supports ephemeral resources for enhanced secret security (secrets not stored in state)

- **S3 Bucket Support**: Added comprehensive S3 bucket management through new `iter_s3.tf` module
  - Configuration-driven S3 bucket creation using `terraform-aws-modules/s3-bucket/aws` module (v5.x)
  - Support for 40+ S3 bucket configuration parameters including:
    - Access control (ACL, public access blocks, object ownership)
    - Security features (encryption, versioning, object lock)
    - Lifecycle rules and intelligent tiering
    - CORS, logging, and website configuration
    - Multiple policy attachments (ELB, CloudTrail, WAF, etc.)
    - Directory buckets (S3 Express One Zone)
  - Configuration structure follows established pattern:
    ```yaml
    s3:
      buckets:
        bucket-name:
          # bucket configuration options
    ```
  - Implemented 8 precondition validations to prevent misconfigurations:
    - Mutual exclusivity between `bucket` and `bucket_prefix`
    - Compatibility checks for ACL/grant usage with object ownership settings
    - Object lock configuration validation
    - Directory bucket parameter validation
    - KMS key requirements for encryption policies
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
