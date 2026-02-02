# Configuration Samples

This document provides YAML configuration examples for all resource types supported by the iter_terraform module. These configurations are placed in your service repository YAML files (e.g., `infra.yml`) and are consumed by the module at plan/apply time.

## Tagging

Tags are passed to the module via the `tags` variable at the module level. Resource-specific tags can be defined within each resource's YAML configuration under a `tags` key. Tags **cannot** be set as a top-level key in the YAML configuration files.

## VPC

Top-level key: `vpcs`

### Minimal VPC

```yaml
vpcs:
  my-vpc:
    cidr: "10.0.0.0/16"
    create_public_subnets: true
    tags:
      Service: "my-service"
```

### Full-featured VPC with endpoints

```yaml
vpcs:
  production-vpc:
    cidr: "10.0.0.0/16"
    az_count: 3
    create_public_subnets: true
    create_database_subnets: true
    create_intra_subnets: false
    enable_nat_gateway: true
    single_nat_gateway: false
    one_nat_gateway_per_az: true
    enable_dns_hostnames: true
    enable_dns_support: true
    enable_flow_log: true
    create_flow_log_cloudwatch_iam_role: true
    create_flow_log_cloudwatch_log_group: true
    flow_log_retention_in_days: 7
    vpc_endpoints:
      endpoint_services:
        s3: {}
        dynamodb: {}
        ecr_dkr: {}
        ecr_api: {}
        rds: {}
    tags:
      Service: "my-service"
      Tier: "application"
```

## S3

Top-level key: `s3`, with a `buckets` sub-key.

### Minimal S3 bucket

```yaml
s3:
  buckets:
    my-bucket:
      bucket: "my-unique-bucket-name"
      versioning:
        enabled: true
```

### S3 bucket with lifecycle rules, encryption, and CORS

```yaml
s3:
  buckets:
    application-data:
      bucket: "my-org-app-data-prod"
      force_destroy: false
      versioning:
        enabled: true
      server_side_encryption_configuration:
        rule:
          apply_server_side_encryption_by_default:
            sse_algorithm: "AES256"
      lifecycle_rule:
        - id: "archive-old-data"
          enabled: true
          transition:
            - days: 90
              storage_class: "GLACIER"
          expiration:
            days: 365
      cors_rule:
        - allowed_headers: ["*"]
          allowed_methods: ["GET", "HEAD"]
          allowed_origins: ["https://example.com"]
          expose_headers: ["ETag"]
          max_age_seconds: 3000
      tags:
        DataType: "application-data"

    log-bucket:
      bucket_prefix: "my-org-logs-"
      attach_lb_log_delivery_policy: true
      lifecycle_rule:
        - id: "log-expiration"
          enabled: true
          expiration:
            days: 90
      tags:
        DataType: "logs"

    backup-bucket:
      bucket: "my-org-backup-prod"
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
              bucket: "arn:aws:s3:::my-org-backup-dr"
              storage_class: "GLACIER"
      tags:
        DataType: "backup"
        Replication: "enabled"
```

## Secrets Manager

Top-level key: `secrets`, with a `secrets` sub-key.

### Minimal secret

```yaml
secrets:
  secrets:
    my-secret:
      description: "Example secret"
      secret_string: "my-secret-value"
```

### Secret with rotation, resource policy, and replication

```yaml
secrets:
  secrets:
    db-password:
      description: "Database master password"
      create_random_password: true
      random_password_length: 32
      recovery_window_in_days: 30
      enable_rotation: true
      rotation_lambda_arn: "arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation"
      rotation_rules:
        automatically_after_days: 30
      tags:
        SecretType: "database-password"

    api-key:
      description: "External API authentication key"
      secret_string: "placeholder-will-be-updated-manually"
      kms_key_id: "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      secret_resource_policy:
        AllowReadAccess:
          sid: "AllowReadAccess"
          effect: "Allow"
          principals:
            - type: "AWS"
              identifiers:
                - "arn:aws:iam::123456789012:role/MyServiceRole"
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
        SecretType: "api-key"

    shared-secret:
      description: "Multi-region replicated secret"
      secret_string: "shared-secret-value"
      replica:
        us-west-2:
          region: "us-west-2"
        eu-west-1:
          region: "eu-west-1"
      tags:
        SecretType: "shared"
        Replicated: "true"
```

## KMS

Top-level key: `kms`, with key name as sub-key.

### Minimal KMS key

```yaml
kms:
  app-encryption-key:
    description: "KMS key for application data encryption"
    deletion_window_in_days: 30
    enable_key_rotation: true
    aliases: ["alias/app-data-key"]
    tags:
      Purpose: "encryption"
      RelatedResource: "application-database"
```

### KMS key with resource policy and multiple aliases

```yaml
kms:
  dynamodb-encryption-key:
    description: "KMS key for DynamoDB table encryption"
    deletion_window_in_days: 30
    enable_key_rotation: true
    rotation_period_in_days: 365
    multi_region: false
    aliases:
      - "alias/dynamodb-table-key"
      - "alias/app-data-encryption"
    resource_policy:
      EnableRootAccess:
        sid: "Enable IAM User Permissions"
        effect: "Allow"
        principals:
          - type: "AWS"
            identifiers: ["arn:aws:iam::123456789012:root"]
        actions: ["kms:*"]
        resources: ["*"]
      AllowDynamoDBService:
        sid: "Allow DynamoDB to use the key"
        effect: "Allow"
        principals:
          - type: "Service"
            identifiers: ["dynamodb.amazonaws.com"]
        actions:
          - "kms:Decrypt"
          - "kms:DescribeKey"
          - "kms:CreateGrant"
        resources: ["*"]
        conditions:
          - test: "StringEquals"
            variable: "kms:ViaService"
            values: ["dynamodb.us-east-1.amazonaws.com"]
    tags:
      Purpose: "encryption"
      RelatedResource: "dynamodb-user-table"

  s3-encryption-key:
    description: "KMS key for S3 bucket encryption"
    deletion_window_in_days: 30
    enable_key_rotation: true
    aliases: ["alias/s3-bucket-key"]
    tags:
      Purpose: "encryption"
      RelatedResource: "s3-data-bucket"
```

## DynamoDB

Top-level key: `dynamodb-tables`, with table name as sub-key.

### Minimal DynamoDB table

```yaml
dynamodb-tables:
  user-sessions:
    create_table: true
    config:
      hash_key: "session_id"
      attributes:
        - name: "session_id"
          type: "S"
      billing_mode: "PAY_PER_REQUEST"
      ttl_enabled: true
      ttl_attribute_name: "expires_at"
      tags:
        Service: "auth"
```

### Full-featured DynamoDB table with streams, custom KMS key, contributor insights, and S3 export

```yaml
dynamodb-tables:
  user-table:
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
      stream_enabled: true
      stream_view_type: "NEW_AND_OLD_IMAGES"
      deletion_protection_enabled: true
      custom-key: true
      contributor_insights:
        enabled: true
      table_export:
        s3_bucket: "my-org-dynamodb-exports"
        s3_prefix: "user-table/"
        export_format: "DYNAMODB_JSON"
      tags:
        Service: "user-management"
```

> **Note:** When `custom-key: true` is set, a KMS key must exist with a `purpose` tag matching the table key name (e.g., `user-table`). See the KMS examples above for how to configure a matching key.

### Provisioned DynamoDB table with autoscaling and global secondary indexes

```yaml
dynamodb-tables:
  audit-log:
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
      global_secondary_indexes:
        - name: "timestamp-index"
          hash_key: "timestamp"
          projection_type: "ALL"
          write_capacity: 5
          read_capacity: 10
```

## Defaults Configuration

The module supports a central defaults file (e.g., `infra_defaults.yml`) to set baseline values for all resources. Resource-level settings in service YAML files override these defaults.

### Example infra_defaults.yml

```yaml
---
# Default VPC settings
vpc:
  az_count: 3
  enable_nat_gateway: true
  single_nat_gateway: true
  enable_dns_hostnames: true
  enable_dns_support: true
  private_subnet_suffix: "private"
  public_subnet_suffix: "public"
  database_subnet_suffix: "db"

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

# Default KMS settings
kms:
  deletion_window_in_days: 30
  enable_key_rotation: true

# Default DynamoDB settings
dynamodb-tables:
  billing_mode: "PAY_PER_REQUEST"
  point_in_time_recovery_enabled: false
  server_side_encryption_enabled: false
```
