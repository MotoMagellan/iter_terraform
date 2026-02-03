# Iterative Terraform

Iteratively build infrastructure to support Serverless and lightweight
Container-based workloads

## Implementation Philosophy

This module is a Terraform-based implementation of GitOps for AWS cloud
environments. With this module, teams can configure sets of cloud resources
using configuration files that reside alongside their product code, making
modification and troubleshooting of settings much more straightforward by the
teams managing the product and its infrastructure.

Infrastructure Management will be supported both for bare individual resources
with no additional related resources and packaged solution sets that contain
resources from multiple AWS services.

Packaged solutions will be offered to deploy sets of infrastructure for a
specific purpose. These sets will be stored under the modules folder and
instantiated iteratively at the base level similarly to the individual
resource types. Sets will include solutions such as globally-replicated
secrets from a central region, Lambdas deployed into many regions from buckets
that are replicated across regions, and RDS Global clusters.

Solution sets will have a top-level configuration key name, and each type of
configured solution sets will have child key-value maps for each solution set
that is configured to be managed and deployed by iter_terraform.

## Usage

```hcl
module "example" {
  source = "github.com/your-org/iter-terraform"

  # Required variables
  config_defaults = {
    service    = "github" # or gitlab -- value is required
    repository = "BigCorpDevops/terraform_projects"
    branch     = "release"
    file_path  = "iter_terraform/infra_defaults.yml"
  }

  config_repo_files = {
    github = [
      {
        repository = "BigCorp/serviceA"
        branch     = "release"
        file_path = "terraform/infra.yml"
      },
    ]
    gitlab = [
      {
        repository = "BigCorp/serviceB"
        branch     = "main" # default
        file_path = "terraform/infra.yml"
      },
    ]
  }

  # Optional variables
  tags = {
    Environment = "dev"
  }
}
```

### VPC Configs

VPCs are defined both individually with a map that contains the key and
values for all of the configuration required for each VPC. The VPC
module will also check for values under the vpc_defaults key, and
use those values when a key is not specified in the config for a 
particular VPC.

#### VPC Functional Documentation

This module utilized the standard AWS VPC Terraform module hosted at the
(Terraform Registry)[https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws].

#### VPC Configuration Example

Configuration Defaults

```yaml
---
vpc:
  az_count: 3
  create_intra_subnets: false
  private_subnet_suffix: "pvt"
  public_subnet_suffix: "pub"
  vpc_endpoints:
    endpoint_services:
      ecr_dkr: {}
```

Example Configuration

```yaml
---
vpcs:
  "main":
    cidr: "10.0.0.0/8"
    create_public_subnets: true
    create_database_subnets: true
    create_intra_subnets: true
    vpc_endpoints:
      endpoint_services:
        s3: {}
        ecr_dkr: {}
  "devops":
    az_count: 2
    vpc_cidr_offset: 1 # creates a VPC with a CIDR of "10.1.0.0/8"
    create_public_subnets: false
    create_database_subnets: true
    create_intra_subnets: true
```

### S3 Configs

S3 buckets are defined individually with a map that contains the key and
values for all of the configuration required for each bucket. The S3
module will also check for values under the s3_defaults key, and use
those values when a key is not specified in the config for a particular
bucket.

The `custom-key` option enables automatic KMS key lookup by matching a KMS
key's `purpose` tag to the bucket's key name. When set to `true`, the module
automatically configures server-side encryption with `aws:kms` algorithm and
bucket key enabled.

#### S3 Functional Documentation

This module utilizes the standard AWS S3 Terraform module hosted at the
[Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws).

#### S3 Configuration Example

Configuration Defaults

```yaml
---
s3:
  force_destroy: false
  block_public_acls: true
  block_public_policy: true
  ignore_public_acls: true
  restrict_public_buckets: true
  control_object_ownership: true
  object_ownership: "BucketOwnerEnforced"
```

Example Configuration

```yaml
---
s3:
  buckets:
    "data-lake":
      bucket: "my-org-data-lake"
      force_destroy: true
      custom-key: true  # Looks up KMS key by 'purpose' tag matching "data-lake"
      versioning:
        enabled: true
    "logs":
      bucket_prefix: "my-org-logs-"
      attach_lb_log_delivery_policy: true
      server_side_encryption_configuration:  # Explicit encryption for externally-managed keys
        rule:
          apply_server_side_encryption_by_default:
            sse_algorithm: "AES256"
      lifecycle_rule:
        - id: "log-expiration"
          enabled: true
          expiration:
            days: 90
```

### Secrets Manager Configs

Secrets Manager secrets are defined individually with a map that contains the key and values for all of the configuration required for each secret. The Secrets Manager module will also check for values under the secrets_defaults key, and use those values when a key is not specified in the config for a particular secret.

The `custom-key` option enables automatic KMS key lookup by matching a KMS key's `purpose` tag to the secret's key name. When set to `true`, the module automatically configures the secret's `kms_key_id` with the looked-up KMS key ARN.

#### Secrets Manager Functional Documentation

This module utilizes the standard AWS Secrets Manager Terraform module hosted at the [Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/secrets-manager/aws).

#### Secrets Manager Configuration Example

Configuration Defaults

```yaml
---
secrets:
  recovery_window_in_days: 30
  block_public_policy: true
  ignore_secret_changes: false
```

Example Configuration

```yaml
---
secrets:
  secrets:
    "database-password":
      description: "RDS database master password"
      create_random_password: true
      random_password_length: 32
      enable_rotation: true
      rotation_lambda_arn: "arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation"
      rotation_rules:
        automatically_after_days: 30
      custom-key: true  # Looks up KMS key by 'purpose' tag matching "database-password"

    "api-key":
      description: "External API authentication key"
      secret_string: "my-secret-api-key-value"
      kms_key_id: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"  # Explicit ARN for externally-managed keys
      secret_resource_policy:
        AllowReadAccess:
          sid: "AllowReadAccess"
          effect: "Allow"
          principals:
            - type: "AWS"
              identifiers: ["arn:aws:iam::123456789012:role/MyApplicationRole"]
          actions: ["secretsmanager:GetSecretValue"]
        DenyExternalAccess:
          sid: "DenyExternalAccess"
          effect: "Deny"
          principals:
            - type: "*"
              identifiers: ["*"]
          actions: ["secretsmanager:*"]
          conditions:
            - test: "StringNotEquals"
              variable: "aws:PrincipalOrgID"
              values: ["o-xxxxxxxxxx"]

    "replicated-secret":
      description: "Multi-region replicated secret"
      secret_string: "shared-secret-value"
      replica:
        us-west-2:
          region: "us-west-2"
        eu-west-1:
          region: "eu-west-1"
          kms_key_id: "arn:aws:kms:eu-west-1:123456789012:key/12345678-1234-1234-1234-123456789012"
```

### KMS Configs

KMS keys are defined individually with a map that contains the key and values for all of the configuration required for each key. The KMS module will also check for values under the kms_defaults key, and use those values when a key is not specified in the config for a particular key.

#### KMS Functional Documentation

This module utilizes the standard AWS KMS Terraform module hosted at the [Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/kms/aws).

#### KMS Configuration Example

Configuration Defaults

```yaml
---
kms:
  deletion_window_in_days: 30
  enable_key_rotation: true
  key_usage: "ENCRYPT_DECRYPT"
  customer_master_key_spec: "SYMMETRIC_DEFAULT"
```

Example Configuration

```yaml
---
kms:
  dynamodb-encryption-key:
    description: "KMS key for DynamoDB table encryption"
    deletion_window_in_days: 30
    enable_key_rotation: true
    aliases:
      - "alias/dynamodb-table-key"
    resource_policy:
      EnableRootAccess:
        sid: "Enable IAM User Permissions"
        effect: "Allow"
        principals:
          - type: "AWS"
            identifiers: ["arn:aws:iam::123456789012:root"]
        actions: ["kms:*"]
        resources: ["*"]
    tags:
      purpose: "user-table"
```

### DynamoDB Table Configs

DynamoDB tables are defined individually with a map that contains the key and values for all of the configuration required for each table. The DynamoDB module will also check for values under the dynamodb-tables defaults key, and use those values when a key is not specified in the config for a particular table.

Each table entry supports a `name` key to override the table name (defaults to the map key), a `create_table` key to control whether the table is created, and a `config` sub-key containing all module parameters. The `custom-key` option under `config` enables automatic KMS key lookup by matching a KMS key's `purpose` tag to the table's key name.

Additional resources can be configured per table: `contributor_insights` enables CloudWatch Contributor Insights, and `table_export` configures point-in-time export to S3.

#### DynamoDB Functional Documentation

This module utilizes the standard AWS DynamoDB Table Terraform module hosted at the [Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/dynamodb-table/aws).

#### DynamoDB Configuration Example

Configuration Defaults

```yaml
---
dynamodb-tables:
  billing_mode: "PAY_PER_REQUEST"
  point_in_time_recovery_enabled: false
  ttl_enabled: false
  server_side_encryption_enabled: false
  stream_enabled: false
  autoscaling_enabled: false
```

Example Configuration

```yaml
---
dynamodb-tables:
  "user-table":
    create_table: true
    config:
      hash_key: "user_id"
      range_key: "sort_key"
      attributes:
        - name: "user_id"
          type: "S"
        - name: "sort_key"
          type: "S"
      billing_mode: "PAY_PER_REQUEST"
      point_in_time_recovery_enabled: true
      ttl_enabled: true
      ttl_attribute_name: "expires_at"
      custom-key: true
      contributor_insights:
        enabled: true
      table_export:
        s3_bucket: "my-org-dynamodb-exports"
        s3_prefix: "user-table/"
        export_format: "DYNAMODB_JSON"

  "audit-log":
    name: "production-audit-log"
    create_table: true
    config:
      hash_key: "event_id"
      range_key: "timestamp"
      attributes:
        - name: "event_id"
          type: "S"
        - name: "timestamp"
          type: "N"
      billing_mode: "PROVISIONED"
      read_capacity: 10
      write_capacity: 5
      autoscaling_enabled: true
      autoscaling_read:
        max_capacity: 100
      autoscaling_write:
        max_capacity: 50
      deletion_protection_enabled: true
      server_side_encryption_enabled: true
```

<!-- BEGIN_TF_DOCS -->


## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | ~> 6.0 |
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.30.0 |
| <a name="provider_github"></a> [github](#provider\_github) | 6.10.2 |
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | 3.20.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_dynamodb_table"></a> [dynamodb\_table](#module\_dynamodb\_table) | terraform-aws-modules/dynamodb-table/aws | ~> 5.0 |
| <a name="module_kms"></a> [kms](#module\_kms) | terraform-aws-modules/kms/aws | ~> 4.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 5.0 |
| <a name="module_secrets_manager"></a> [secrets\_manager](#module\_secrets\_manager) | terraform-aws-modules/secrets-manager/aws | ~> 2.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 6.6.0 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | terraform-aws-modules/vpc/aws//modules/vpc-endpoints | 6.6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_contributor_insights.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_contributor_insights) | resource |
| [aws_dynamodb_table_export.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_export) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [terraform_data.dynamodb_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.kms_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.s3_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.secrets_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.vpc_config_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.dynamodb_endpoint_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.generic_endpoint_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [github_repository_file.config_defaults](https://registry.terraform.io/providers/hashicorp/github/latest/docs/data-sources/repository_file) | data source |
| [github_repository_file.github_infra_configs](https://registry.terraform.io/providers/hashicorp/github/latest/docs/data-sources/repository_file) | data source |
| [gitlab_repository_file.config_defaults](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/data-sources/repository_file) | data source |
| [gitlab_repository_file.gitlab_infra_configs](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/data-sources/repository_file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_config_defaults"></a> [config\_defaults](#input\_config\_defaults) | Map of Git providers (github/gitlab) to their repository file configurations | <pre>map(object({<br/>    service    = string<br/>    repository = optional(string)<br/>    branch     = optional(string)<br/>    file_path  = string<br/>    project    = optional(string)<br/>    ref        = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_config_repo_files"></a> [config\_repo\_files](#input\_config\_repo\_files) | Map of Git providers (github/gitlab) to their repository file configurations | <pre>map(list(object({<br/>    repository = optional(string)<br/>    branch     = optional(string)<br/>    file_path  = string<br/>    project    = optional(string)<br/>    ref        = optional(string)<br/>  })))</pre> | n/a | yes |
| <a name="input_default_config_branch"></a> [default\_config\_branch](#input\_default\_config\_branch) | The default branch that config files should be queried from | `string` | `"main"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dynamodb_tables"></a> [dynamodb\_tables](#output\_dynamodb\_tables) | Map of DynamoDB table resources created by the module |
| <a name="output_infra_configs"></a> [infra\_configs](#output\_infra\_configs) | Merged infrastructure configurations from all specified repositories |
| <a name="output_kms_keys"></a> [kms\_keys](#output\_kms\_keys) | Map of KMS key resources created by the module |
| <a name="output_s3_buckets"></a> [s3\_buckets](#output\_s3\_buckets) | Map of S3 bucket resources created by the module |
| <a name="output_secrets"></a> [secrets](#output\_secrets) | Map of Secrets Manager resources created by the module |
| <a name="output_vpc_endpoints"></a> [vpc\_endpoints](#output\_vpc\_endpoints) | Map of VPC endpoint resources created by the module |
| <a name="output_vpcs"></a> [vpcs](#output\_vpcs) | Map of VPC resources created by the module |
<!-- END_TF_DOCS -->

## License

Apache 2.0 Licensed. See [LICENSE](LICENSE) for full details.
