# Complete Example

This example demonstrates a comprehensive configuration using all features of the iter_terraform module.

## Overview

This complete example demonstrates:
- Multiple Git repository sources (GitHub and GitLab)
- Complex VPC configurations with VPC endpoints
- Multiple S3 buckets with various security settings
- AWS Secrets Manager secrets with rotation
- Comprehensive tagging and resource organization
- Multi-region configurations

## Architecture

The example creates:
- **VPCs**: Multiple VPCs with public, private, and database subnets
- **VPC Endpoints**: Interface and gateway endpoints for AWS services
- **S3 Buckets**: Data lake, logs, and application buckets
- **Secrets**: Database credentials, API keys, and replicated secrets

## Configuration Files

### infra_defaults.yml (Central defaults repository)

```yaml
---
# Default VPC settings
vpc:
  az_count: 3
  enable_nat_gateway: true
  single_nat_gateway: false
  one_nat_gateway_per_az: true
  enable_dns_hostnames: true
  enable_dns_support: true
  private_subnet_suffix: "private"
  public_subnet_suffix: "public"
  database_subnet_suffix: "db"

  # Default VPC endpoints
  vpc_endpoints:
    endpoint_services:
      ecr_dkr: {}
      ecr_api: {}
      s3: {}

# Default S3 settings
s3:
  force_destroy: false
  block_public_acls: true
  block_public_policy: true
  ignore_public_acls: true
  restrict_public_buckets: true
  control_object_ownership: true
  object_ownership: "BucketOwnerEnforced"

  versioning:
    enabled: true

  server_side_encryption_configuration:
    rule:
      apply_server_side_encryption_by_default:
        sse_algorithm: "AES256"

# Default Secrets Manager settings
secrets:
  recovery_window_in_days: 30
  block_public_policy: true
  ignore_secret_changes: false
```

### service-a/terraform/infra.yml

```yaml
---
vpcs:
  service-a-main:
    cidr: "10.0.0.0/16"
    create_public_subnets: true
    create_database_subnets: true
    create_intra_subnets: false

    # Override default: use single NAT gateway for dev
    single_nat_gateway: true

    # VPC endpoints for service-a
    vpc_endpoints:
      endpoint_services:
        s3: {}
        ecr_dkr: {}
        ecr_api: {}
        rds: {}

    tags:
      Service: "service-a"
      Tier: "application"

s3:
  buckets:
    service-a-data:
      bucket: "example-service-a-data-prod"
      force_destroy: false

      lifecycle_rule:
        - id: "archive-old-data"
          enabled: true
          transition:
            - days: 90
              storage_class: "GLACIER"
          expiration:
            days: 365

      tags:
        Service: "service-a"
        DataType: "application-data"

secrets:
  secrets:
    service-a-db-password:
      description: "Service A database master password"
      create_random_password: true
      random_password_length: 32
      enable_rotation: true
      rotation_lambda_arn: "arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation"
      rotation_rules:
        automatically_after_days: 30

      tags:
        Service: "service-a"
        SecretType: "database-password"
```

### service-b/infrastructure/config.yml

```yaml
---
vpcs:
  service-b-main:
    cidr: "10.1.0.0/16"
    az_count: 2
    create_public_subnets: false
    create_database_subnets: true
    create_intra_subnets: true

    # High availability: NAT gateway per AZ
    single_nat_gateway: false
    one_nat_gateway_per_az: true

    # Enable VPC flow logs
    enable_flow_log: true
    create_flow_log_cloudwatch_iam_role: true
    create_flow_log_cloudwatch_log_group: true
    flow_log_retention_in_days: 7

    tags:
      Service: "service-b"
      Tier: "backend"

s3:
  buckets:
    service-b-logs:
      bucket_prefix: "example-service-b-logs-"
      attach_lb_log_delivery_policy: true

      lifecycle_rule:
        - id: "log-expiration"
          enabled: true
          expiration:
            days: 90

      tags:
        Service: "service-b"
        DataType: "logs"

    service-b-backup:
      bucket: "example-service-b-backup-prod"
      force_destroy: false

      versioning:
        enabled: true
        mfa_delete: false

      replication_configuration:
        role: "arn:aws:iam::123456789012:role/s3-replication-role"
        rules:
          - id: "replicate-to-dr"
            status: "Enabled"
            destination:
              bucket: "arn:aws:s3:::example-service-b-backup-dr"
              storage_class: "GLACIER"

      tags:
        Service: "service-b"
        DataType: "backup"
        Replication: "enabled"

secrets:
  secrets:
    service-b-api-key:
      description: "Service B external API authentication key"
      secret_string: "placeholder-will-be-updated-manually"

      secret_resource_policy:
        AllowReadAccess:
          sid: "AllowReadAccess"
          effect: "Allow"
          principals:
            - type: "AWS"
              identifiers:
                - "arn:aws:iam::123456789012:role/ServiceBRole"
          actions:
            - "secretsmanager:GetSecretValue"
        DenyExternalAccess:
          sid: "DenyExternalAccess"
          effect: "Deny"
          principals:
            - type: "*"
              identifiers: ["*"]
          actions:
            - "secretsmanager:*"
          conditions:
            - test: "StringNotEquals"
              variable: "aws:PrincipalOrgID"
              values: ["o-xxxxxxxxxx"]

      tags:
        Service: "service-b"
        SecretType: "api-key"
```

### service-c/terraform/infra.yml (GitLab)

```yaml
---
vpcs:
  service-c-main:
    cidr: "10.2.0.0/16"
    create_public_subnets: true
    create_database_subnets: true

    vpc_endpoints:
      endpoint_services:
        s3: {}
        dynamodb: {}
        ecr_dkr: {}

    tags:
      Service: "service-c"
      Source: "gitlab"

s3:
  buckets:
    service-c-assets:
      bucket: "example-service-c-assets-prod"

      cors_rule:
        - allowed_headers: ["*"]
          allowed_methods: ["GET", "HEAD"]
          allowed_origins: ["https://example.com"]
          expose_headers: ["ETag"]
          max_age_seconds: 3000

      tags:
        Service: "service-c"
        DataType: "public-assets"

secrets:
  secrets:
    service-c-shared-secret:
      description: "Multi-region replicated secret for service C"
      secret_string: "shared-secret-value"

      replica:
        us-west-2:
          region: "us-west-2"
        eu-west-1:
          region: "eu-west-1"

      tags:
        Service: "service-c"
        SecretType: "shared"
        Replicated: "true"
```

## Prerequisites

1. **AWS Authentication**: Configure AWS credentials
   ```bash
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   ```

2. **GitHub Authentication**: Set GitHub token
   ```bash
   export GITHUB_TOKEN="your-github-token"
   ```

3. **GitLab Authentication**: Set GitLab token
   ```bash
   export GITLAB_TOKEN="your-gitlab-token"
   ```

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. View outputs:
   ```bash
   terraform output
   ```

## Expected Resources

This example will create:

### VPCs (3 total)
- `service-a-main`: 10.0.0.0/16 with public, private, and database subnets
- `service-b-main`: 10.1.0.0/16 with private, database, and intra subnets
- `service-c-main`: 10.2.0.0/16 with public, private, and database subnets

### VPC Endpoints
- S3 gateway endpoints
- ECR (API and DKR) interface endpoints
- RDS interface endpoints
- DynamoDB gateway endpoints

### S3 Buckets (5 total)
- `service-a-data`: Application data with lifecycle policies
- `service-b-logs`: Log storage with expiration
- `service-b-backup`: Versioned backup with replication
- `service-c-assets`: Public assets with CORS

### Secrets (4 total)
- `service-a-db-password`: Auto-generated with rotation
- `service-b-api-key`: Manual secret with resource policy
- `service-c-shared-secret`: Multi-region replicated

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| N/A | This example is fully self-contained | N/A | N/A | N/A |

## Outputs

| Name | Description |
|------|-------------|
| infra_configs | Merged infrastructure configurations (sensitive) |
| vpc_details | Details of all created VPCs including subnets and NAT gateways |
| s3_bucket_details | ARNs and domain names of all S3 buckets |
| secrets_details | ARNs of all created secrets (sensitive) |

## Requirements

- Terraform >= 1.0
- AWS, GitHub, and GitLab provider credentials configured
- Configuration files must exist in the specified repositories

## Cost Considerations

This example creates resources that incur costs:
- NAT Gateways (per AZ, per hour + data transfer)
- VPC Endpoints (per endpoint, per hour + data transfer)
- S3 storage and requests
- Secrets Manager secrets (per secret per month)
- VPC Flow Logs (CloudWatch Logs storage)

Estimated monthly cost: $200-500 depending on usage.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Note: Some resources (S3 buckets, secrets) may have retention policies that prevent immediate deletion.

## Features Demonstrated

- Multiple Git repository sources (GitHub and GitLab)
- Complex VPC configurations with VPC endpoints
- Multiple S3 buckets with various security settings
- AWS Secrets Manager secrets with rotation
- Comprehensive tagging and resource organization
- Multi-region configurations

## Notes

- Configuration files must exist in the specified repositories before running
- Secrets with `ignore_secret_changes: true` won't be updated by Terraform after creation
- VPC endpoint costs can add up quickly - only enable needed services
- Consider using `single_nat_gateway: true` for dev environments to reduce costs
- S3 bucket names must be globally unique - update the examples with your own bucket names
