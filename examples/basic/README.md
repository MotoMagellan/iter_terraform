# Basic Example

This example demonstrates the minimal configuration needed to use the iter_terraform module.

## Overview

This basic example shows:
- Single GitHub repository configuration
- Minimal required parameters
- Configuration-driven infrastructure (VPC, S3, Secrets Manager)
- Basic tagging strategy

## Configuration Files

The module expects YAML configuration files in your repositories with the following structure:

### infra_defaults.yml (in infrastructure-defaults repo)

```yaml
---
# VPC defaults applied to all VPCs
vpc:
  az_count: 3
  enable_nat_gateway: true
  single_nat_gateway: true
  enable_dns_hostnames: true
  enable_dns_support: true
  private_subnet_suffix: "private"
  public_subnet_suffix: "public"
```

### infra.yml (in service-a repo)

```yaml
---
# VPC Configuration
vpcs:
  main:
    cidr: "10.0.0.0/16"
    create_public_subnets: true
    create_database_subnets: true
    tags:
      Service: "service-a"

# S3 Bucket Configuration (optional)
s3:
  buckets:
    example-bucket:
      bucket: "my-example-bucket-name"
      versioning:
        enabled: true

# Secrets Manager Configuration (optional)
secrets:
  secrets:
    example-secret:
      description: "Example secret"
      secret_string: "my-secret-value"
```

## Usage

1. Ensure you have GitHub authentication configured:
   ```bash
   export GITHUB_TOKEN="your-token-here"
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Plan the deployment:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| N/A | This example uses the module's default configuration | N/A | N/A | N/A |

## Outputs

| Name | Description |
|------|-------------|
| infra_configs | Merged infrastructure configurations from all repositories |
| vpcs | All VPC resources created |
| vpc_ids | Map of VPC names to their IDs |
| s3_buckets | All S3 bucket resources created |
| secrets | All Secrets Manager resources created (sensitive) |

## Requirements

- Terraform >= 1.0
- GitHub authentication via token or GitHub App
- Configuration files must exist in the specified repositories
- All VPCs will be created in the AWS region specified in the provider configuration

## Notes

- This example requires GitHub authentication via token or GitHub App
- The configuration files must exist in the specified repositories
- All VPCs will be created in the AWS region specified in the provider configuration
